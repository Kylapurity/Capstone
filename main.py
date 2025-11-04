"""
FastAPI Application for Egg Production Prediction
Corrected to match your actual 5 features: 
- amount_of_chicken, ammonia, temperature, humidity, light_intensity
"""

from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, field_validator
from typing import Optional, List, Dict
from contextlib import asynccontextmanager
import numpy as np
import joblib
import os
from datetime import datetime
import logging
# Workaround for protobuf / tensorflow compatibility issues on some environments.
# Use the pure-Python protobuf implementation to avoid the "Descriptors cannot be created directly" error
# See: https://developers.google.com/protocol-buffers/docs/news/2022-05-06#python-updates
os.environ.setdefault("PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION", "python")
from pathlib import Path

# Configure logging FIRST
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Import TensorFlow/Keras early to ensure proper initialization
keras = None
tf = None

# Try importing keras first (works with both standalone keras and tensorflow.keras)
try:
    import keras
    logger.info("✅ Keras imported successfully")
except ImportError as e:
    logger.warning(f"⚠️  Failed to import standalone keras: {e}")
    try:
        import tensorflow as tf
        from tensorflow import keras
        logger.info("✅ Keras imported from TensorFlow")
    except ImportError as e2:
        logger.error(f"❌ Failed to import TensorFlow/Keras: {e2}")

# Global variables for model and scalers
model = None
scaler_X = None
# Store the last model load error (traceback) for diagnostics
last_load_error: Optional[str] = None

# Resolve project root and model/scaler paths. Prefer env var but fall back to common filenames.
BASE_DIR = Path(__file__).resolve().parent
MODELS_DIR = BASE_DIR / "models"
env_model_path = os.environ.get("MODEL_PATH")
if env_model_path:
    MODEL_PATH = Path(env_model_path)
else:
    # Try common filenames in models directory (prioritize newly trained .h5 model)
    possible = [
        MODELS_DIR / "sequence_model.h5",
        MODELS_DIR / "sequence_model.keras", 
        MODELS_DIR / "sequence_model (1).keras",  # fallback to old file
    ]
    MODEL_PATH = next((p for p in possible if p.exists()), possible[0])

SCALER_X_PATH = Path(os.environ.get("SCALER_X_PATH", str(MODELS_DIR / "scaler_X.pkl")))

# Initialize FastAPI app
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan handler: runs at startup to load the model and can handle shutdown tasks."""
    logger.info("Starting Egg Production API (lifespan)...")
    success = load_model()
    if not success:
        logger.error("CRITICAL: Model failed to load. API will not function properly.")
    yield


app = FastAPI(
    title="Egg Production Prediction API",
    description="API for predicting egg production based on environmental factors",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic models for request/response validation
class FarmInput(BaseModel):
    """Input schema for egg production prediction - 7 features"""
    amount_of_chicken: float = Field(..., ge=10, le=10000, description="Number of chickens (10-10000)")
    amount_of_feeding: float = Field(..., ge=24.6, le=675.9, description="Amount of feeding (24.6-675.9)")
    ammonia: float = Field(..., ge=2.0, le=53.5, description="Ammonia level in ppm (2.0-53.5)")
    temperature: float = Field(..., ge=5.0, le=45.0, description="Temperature in Celsius (5.0-45.0)")
    humidity: float = Field(..., ge=36.9, le=95.0, description="Humidity percentage (36.9-95.0)")
    light_intensity: float = Field(..., ge=97.5, le=929.2, description="Light intensity in lux (97.5-929.2)")
    noise: float = Field(..., ge=64.4, le=607.3, description="Noise level (64.4-607.3)")

    # Pydantic v2 configuration: use model_config
    model_config = {
        "json_schema_extra": {
            "example": {
                "amount_of_chicken": 2291.0,
                "amount_of_feeding": 258.6,
                "ammonia": 17.5,
                "temperature": 27.0,
                "humidity": 59.4,
                "light_intensity": 481.8,
                "noise": 236.3
            }
        }
    }

    @field_validator('humidity')
    def validate_humidity(cls, v):
        if not 36.9 <= v <= 95.0:
            raise ValueError('Humidity must be between 36.9 and 95.0')
        return v


class PredictionResponse(BaseModel):
    """Response schema for prediction"""
    predicted_egg_production: float = Field(..., description="Predicted total egg production")
    confidence_score: float = Field(..., description="Model confidence score (0-1)")
    farm_size_category: str = Field(..., description="Farm size category")
    recommendations: List[str] = Field(..., description="Optimization recommendations")
    timestamp: str = Field(..., description="Prediction timestamp")
    model_version: str = Field(..., description="Model version used")
    input_data: Dict = Field(..., description="Input data used for prediction")
    # Avoid Pydantic protected namespace warnings for fields starting with "model_"
    model_config = {"protected_namespaces": ()}


class HealthResponse(BaseModel):
    """Health check response"""
    status: str
    model_loaded: bool
    scaler_X_loaded: bool
    last_error: Optional[str]
    timestamp: str
    version: str
    # Avoid Pydantic protected namespace warnings for fields starting with "model_"
    model_config = {"protected_namespaces": ()}


class BatchPredictionInput(BaseModel):
    """Input for batch predictions"""
    farms: List[FarmInput] = Field(..., max_items=100, description="List of farm inputs (max 100)")


class BatchPredictionResponse(BaseModel):
    """Response for batch predictions"""
    predictions: List[PredictionResponse]
    total_predictions: int
    timestamp: str


# Utility functions
def load_model():
    """Load the trained model and scalers - SPECIFICALLY sequence_model.h5"""
    global model, scaler_X, last_load_error
    try:
        logger.info("Loading model and scalers...")

        # Prepare list of candidate model files
        model_candidates = []
        if isinstance(MODEL_PATH, (str,)):
            model_candidates = [Path(MODEL_PATH)]
        else:
            model_candidates = [MODEL_PATH]

        # If the candidate doesn't exist, check common alternatives in MODELS_DIR and BASE_DIR
        if not model_candidates[0].exists():
            alt = [
                MODELS_DIR / "sequence_model_fixed.h5", 
                MODELS_DIR / "sequence_model_compatible.h5",
                MODELS_DIR / "sequence_model.h5", 
                MODELS_DIR / "sequence_model.keras", 
                MODELS_DIR / "sequence_model",
                BASE_DIR / "sequence_model_fixed.h5", 
                BASE_DIR / "sequence_model.h5", 
                BASE_DIR / "sequence_model.keras", 
                BASE_DIR / "sequence_model"
            ]
            model_candidates = [p for p in alt if p.exists()]

        if not model_candidates:
            raise FileNotFoundError(f"Model file not found. Checked: {MODELS_DIR / 'sequence_model.h5'}, {MODELS_DIR / 'sequence_model.keras'}, {BASE_DIR / 'sequence_model.h5'}; or set MODEL_PATH env var.")

        selected_model = model_candidates[0]
        logger.info(f"Attempting to load Keras model from: {selected_model}")
        
        if keras is None:
            raise RuntimeError("TensorFlow/Keras not properly installed. Please install: pip install tensorflow>=2.16.0")
        
        import h5py

        # Try several load strategies for compatibility
        load_errors = []
        
        # Strategy 1: Standard load with keras
        try:
            model = keras.models.load_model(str(selected_model), compile=False)
            logger.info("✅ Keras model loaded successfully (keras.models.load_model)")
        except Exception as e1:
            load_errors.append(f"Standard load: {str(e1)}")
            logger.warning(f"keras.models.load_model failed: {e1}")
            
            # Strategy 2: Try with tf.keras if tf is available
            if tf is not None:
                try:
                    model = tf.keras.models.load_model(str(selected_model), compile=False)
                    logger.info("✅ Keras model loaded successfully (tf.keras.models.load_model)")
                except Exception as e2:
                    load_errors.append(f"TF Keras load: {str(e2)}")
                    logger.warning(f"tf.keras.models.load_model failed: {e2}")
                    
                    # Strategy 3: Manual reconstruction from H5 file (for batch_shape compatibility)
                    try:
                        logger.info("Attempting manual model reconstruction from H5 file...")
                        with h5py.File(str(selected_model), 'r') as f:
                            # Load model config
                            if 'model_config' in f.attrs:
                                import json
                                config = json.loads(f.attrs['model_config'])
                                
                                # Fix batch_shape -> input_shape in config
                                if 'config' in config and 'layers' in config['config']:
                                    for layer in config['config']['layers']:
                                        if 'config' in layer and 'batch_shape' in layer['config']:
                                            batch_shape = layer['config']['batch_shape']
                                            # Convert batch_shape to input_shape (remove batch dimension)
                                            if batch_shape and len(batch_shape) > 1:
                                                layer['config']['input_shape'] = batch_shape[1:]
                                            del layer['config']['batch_shape']
                                
                                # Reconstruct model from modified config
                                model = tf.keras.models.model_from_json(json.dumps(config))
                                
                                # Load weights
                                model.load_weights(str(selected_model))
                                logger.info("✅ Model reconstructed successfully with compatibility fixes")
                            else:
                                raise ValueError("No model_config found in H5 file")
                                
                    except Exception as e3:
                        load_errors.append(f"Manual reconstruction: {str(e3)}")
                        logger.error("All attempts to load the Keras model failed")
                        raise RuntimeError("; ".join(load_errors))
            else:
                logger.error("TensorFlow not available, skipping tf.keras strategies")
                raise RuntimeError("; ".join(load_errors))

        # Load scaler for X (features only - target is not scaled)
        scaler_path = Path(SCALER_X_PATH)
        if not scaler_path.exists():
            fallbacks = [MODELS_DIR / "scaler_X.pkl", BASE_DIR / "scaler_X.pkl"]
            scaler_path = next((p for p in fallbacks if p.exists()), None)
            if scaler_path is None:
                raise FileNotFoundError(f"Scaler X file '{SCALER_X_PATH}' not found. Checked fallbacks: {fallbacks}")

        scaler_X = joblib.load(str(scaler_path))
        logger.info("✅ Scaler loaded successfully")

        # Sanity test the model with a sample prediction (non-invasive)
        try:
            logger.info("Testing model with sample input...")
            test_input = np.array([[2291.0, 258.6, 17.5, 27.0, 59.4, 481.8, 236.3]])
            test_scaled = scaler_X.transform(test_input)
            test_prediction = model.predict(test_scaled, verbose=0)
            test_output = float(np.ravel(test_prediction)[0])
            logger.info(f"✅ Model test successful. Sample prediction: {test_output:.2f}")
        except Exception as e:
            logger.warning(f"Model loaded but sample prediction test failed: {e}")

        return True
        
    except Exception as e:
        logger.error(f"❌ Error loading model: {str(e)}")
        import traceback
        tb = traceback.format_exc()
        logger.error(f"Full traceback: {tb}")

        # Reset global variables to ensure clean state
        model = None
        scaler_X = None
        # Record the error for /health diagnostics
        try:
            last_load_error = tb
        except Exception:
            last_load_error = str(e)
        return False


def get_farm_size_category(num_chickens: float) -> str:
    """Categorize farm size based on number of chickens"""
    if num_chickens < 500:
        return "Small Farm"
    elif num_chickens < 2000:
        return "Medium Farm"
    elif num_chickens < 5000:
        return "Large Farm"
    else:
        return "Industrial Farm"


def generate_recommendations(input_data: FarmInput, prediction: float) -> List[str]:
    """Generate optimization recommendations based on input parameters"""
    recommendations = []
    
    # Temperature recommendations (Optimal: 18-28°C)
    if input_data.temperature < 18:
        recommendations.append("🌡️ Temperature is low. Consider heating to maintain optimal range (18-28°C)")
    elif input_data.temperature > 28:
        recommendations.append("🌡️ Temperature is high. Consider cooling to prevent heat stress")
    else:
        recommendations.append("✅ Temperature is optimal")
    
    # Humidity recommendations (Optimal: 50-70%)
    if input_data.humidity < 50:
        recommendations.append("💧 Humidity is low. Increase humidity to 50-70% for better production")
    elif input_data.humidity > 70:
        recommendations.append("💧 Humidity is high. Reduce to prevent respiratory issues")
    else:
        recommendations.append("✅ Humidity is optimal")
    
    # Ammonia recommendations (Optimal: <25 ppm)
    if input_data.ammonia > 25:
        recommendations.append("🌫️ High ammonia levels detected. Improve ventilation immediately")
    elif input_data.ammonia > 15:
        recommendations.append("⚠️ Ammonia levels are elevated. Monitor ventilation")
    else:
        recommendations.append("✅ Ammonia levels are safe")
    
    # Light intensity recommendations (Optimal: 200-500 lux)
    if input_data.light_intensity < 200:
        recommendations.append("💡 Light intensity is low. Increase to 250-400 lux for optimal egg production")
    elif input_data.light_intensity > 500:
        recommendations.append("💡 Light intensity is high. Reduce to prevent stress")
    else:
        recommendations.append("✅ Light intensity is optimal")
    
    # Amount of feeding recommendations (Optimal: 200-300)
    if input_data.amount_of_feeding < 150:
        recommendations.append("🥗 Feeding amount is low. Increase to ensure adequate nutrition")
    elif input_data.amount_of_feeding > 350:
        recommendations.append("🥗 Feeding amount is high. Monitor to prevent overfeeding")
    else:
        recommendations.append("✅ Feeding amount is optimal")
    
    # Noise recommendations (Optimal: <200)
    if input_data.noise > 300:
        recommendations.append("🔊 Noise level is high. Reduce noise to minimize stress on chickens")
    elif input_data.noise > 200:
        recommendations.append("🔊 Noise level is elevated. Consider soundproofing measures")
    else:
        recommendations.append("✅ Noise level is optimal")
    
    # Production prediction feedback
    expected_production = input_data.amount_of_chicken * 0.8  # ~80% production rate
    if prediction < expected_production * 0.7:
        recommendations.append("📉 Predicted production is below expected. Check environmental conditions")
    elif prediction >= expected_production * 0.9:
        recommendations.append("🎉 Excellent! Predicted production is high. Maintain current conditions")
    
    return recommendations


def calculate_confidence(input_data: FarmInput) -> float:
    """Calculate a confidence score based on input parameter quality"""
    score = 1.0
    
    # Penalize extreme values
    if input_data.temperature < 15 or input_data.temperature > 32:
        score *= 0.85
    if input_data.humidity < 40 or input_data.humidity > 80:
        score *= 0.9
    if input_data.ammonia > 30:
        score *= 0.8
    if input_data.light_intensity < 100 or input_data.light_intensity > 800:
        score *= 0.9
    if input_data.amount_of_feeding < 100 or input_data.amount_of_feeding > 500:
        score *= 0.85
    if input_data.noise > 400:
        score *= 0.85
    
    return round(score, 3)


# API Endpoints
@app.get("/", tags=["Root"])
async def root():
    """Root endpoint with API information"""
    return {
        "message": "Egg Production Prediction API",
        "version": "1.0.0",
        "model": "Keras Neural Network (sequence_model.h5)",
        "features": [
            "amount_of_chicken",
            "amount_of_feeding",
            "ammonia",
            "temperature",
            "humidity",
            "light_intensity",
            "noise"
        ],
        "feature_count": 7,
        "docs": "/docs",
        "health": "/health",
        "endpoints": {
            "predict": "/predict",
            "batch_predict": "/batch_predict",
            "model_info": "/model/info",
            "recommendations": "/recommendations"
        }
    }


@app.get("/health", response_model=HealthResponse, tags=["Health"])
async def health_check():
    """Health check endpoint"""
    return HealthResponse(
        status="healthy" if (model is not None and scaler_X is not None) else "unhealthy",
        model_loaded=model is not None,
        scaler_X_loaded=scaler_X is not None,
        last_error=last_load_error,
        timestamp=datetime.now().isoformat(),
        version="1.0.0"
    )


@app.post("/predict", response_model=PredictionResponse, tags=["Prediction"])
async def predict(farm_data: FarmInput):
    """
    Predict egg production for a single farm
    
    **Required Parameters (7 features):**
    - **amount_of_chicken**: Number of chickens (10-10000)
    - **amount_of_feeding**: Amount of feeding (24.6-675.9)
    - **ammonia**: Ammonia level in ppm (2.0-53.5)
    - **temperature**: Temperature in Celsius (5.0-45.0)
    - **humidity**: Humidity percentage (36.9-95.0)
    - **light_intensity**: Light intensity in lux (97.5-929.2)
    - **noise**: Noise level (64.4-607.3)
    
    
    **Returns:**
    - Predicted egg production
    - Confidence score
    - Recommendations for optimization
    """
    if model is None or scaler_X is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Model not loaded. Please check server logs and ensure sequence_model.h5 is available."
        )
    
    try:
        # Prepare input data in correct order
        input_array = np.array([[
            farm_data.amount_of_chicken,
            farm_data.amount_of_feeding,
            farm_data.ammonia,
            farm_data.temperature,
            farm_data.humidity,
            farm_data.light_intensity,
            farm_data.noise
        ]])
        
        # Scale input
        input_scaled = scaler_X.transform(input_array)
        
        # Make prediction (model outputs actual values, no inverse transform needed)
        prediction_output = model.predict(input_scaled, verbose=0)
        
        # Extract prediction value
        prediction = float(prediction_output[0][0])
        prediction = max(0, prediction)  # Ensure non-negative
        
        # Generate metadata
        farm_category = get_farm_size_category(farm_data.amount_of_chicken)
        confidence = calculate_confidence(farm_data)
        recommendations = generate_recommendations(farm_data, prediction)
        
        return PredictionResponse(
            predicted_egg_production=round(prediction, 2),
            confidence_score=confidence,
            farm_size_category=farm_category,
            recommendations=recommendations,
            timestamp=datetime.now().isoformat(),
            model_version="Keras Neural Network v1.0 (sequence_model.h5)",
            input_data=farm_data.dict()
        )
    
    except Exception as e:
        logger.error(f"Prediction error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Prediction failed: {str(e)}"
        )


@app.post("/batch_predict", response_model=BatchPredictionResponse, tags=["Prediction"])
async def batch_predict(batch_data: BatchPredictionInput):
    """
    Predict egg production for multiple farms (max 100)
    
    Accepts a list of farm inputs and returns predictions for each.
    """
    if model is None or scaler_X is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Model not loaded. Please check server logs and ensure sequence_model.h5 is available."
        )
    
    try:
        predictions = []
        
        for farm_data in batch_data.farms:
            # Prepare input data
            input_array = np.array([[
                farm_data.amount_of_chicken,
                farm_data.amount_of_feeding,
                farm_data.ammonia,
                farm_data.temperature,
                farm_data.humidity,
                farm_data.light_intensity,
                farm_data.noise
            ]])
            
            # Scale input
            input_scaled = scaler_X.transform(input_array)
            
            # Make prediction (model outputs actual values, no inverse transform needed)
            prediction_output = model.predict(input_scaled, verbose=0)
            prediction = float(prediction_output[0][0])
            prediction = max(0, prediction)
            
            # Generate metadata
            farm_category = get_farm_size_category(farm_data.amount_of_chicken)
            confidence = calculate_confidence(farm_data)
            recommendations = generate_recommendations(farm_data, prediction)
            
            predictions.append(PredictionResponse(
                predicted_egg_production=round(prediction, 2),
                confidence_score=confidence,
                farm_size_category=farm_category,
                recommendations=recommendations,
                timestamp=datetime.now().isoformat(),
                model_version="Keras Neural Network v1.0 (sequence_model.h5)",
                input_data=farm_data.dict()
            ))
        
        return BatchPredictionResponse(
            predictions=predictions,
            total_predictions=len(predictions),
            timestamp=datetime.now().isoformat()
        )
    
    except Exception as e:
        logger.error(f"Batch prediction error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Batch prediction failed: {str(e)}"
        )


@app.get("/model/info", tags=["Model"])
async def model_info():
    """Get information about the loaded model"""
    if model is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Model not loaded"
        )
    
    model_summary = []
    try:
        # Try to get model summary
        model.summary(print_fn=lambda x: model_summary.append(x))
        model_summary = "\n".join(model_summary)
    except:
        model_summary = "Model loaded successfully"
    
    return {
        "model_type": "Keras Neural Network",
        "model_file": "sequence_model.h5",
        "version": "1.0.0",
        "features": [
            "amount_of_chicken",
            "amount_of_feeding",
            "ammonia",
            "temperature",
            "humidity",
            "light_intensity",
            "noise"
        ],
        "feature_count": 7,
        "target": "Total_egg_production",
        "input_shape": model.input_shape if hasattr(model, 'input_shape') else "Unknown",
        "output_shape": model.output_shape if hasattr(model, 'output_shape') else "Unknown",
        "summary": model_summary,
        "optimal_ranges": {
            "temperature": "18-28°C",
            "humidity": "50-70%",
            "ammonia": "<25 ppm",
            "light_intensity": "200-500 lux",
            "amount_of_feeding": "200-300",
            "noise": "<200"
        }
    }


@app.get("/recommendations", tags=["Recommendations"])
async def get_general_recommendations():
    """Get general farm management recommendations"""
    return {
        "environmental_conditions": {
            "temperature": {
                "optimal_range": "18-28°C",
                "recommendation": "Maintain consistent temperature to avoid stress. Use heating in winter, cooling in summer."
            },
            "humidity": {
                "optimal_range": "50-70%",
                "recommendation": "Proper humidity prevents respiratory issues. Use ventilation and moisture control."
            },
            "ammonia": {
                "optimal_range": "<25 ppm",
                "recommendation": "Good ventilation is crucial. Clean bedding regularly. Ammonia above 25ppm is dangerous."
            },
            "light_intensity": {
                "optimal_range": "200-500 lux",
                "recommendation": "14-16 hours of light per day for optimal egg production. Use timers for consistency."
            }
        },
        "general_tips": [
            "Maintain clean and dry bedding",
            "Ensure fresh water is always available",
            "Regular health checks and vaccination",
            "Proper spacing (3-4 chickens per square meter)",
            "Consistent daily routine reduces stress",
            "Monitor environmental conditions daily",
            "Adjust based on seasonal changes"
        ],
        "data_collection": {
            "sensors": [
                "DHT11 - Temperature & Humidity",
                "MQ135 - Ammonia/CO2 levels",
                "LDR - Light intensity"
            ],
            "frequency": "Monitor continuously, record every 60 seconds"
        }
    }


# Error handlers
@app.exception_handler(ValueError)
async def value_error_handler(request, exc):
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={"detail": str(exc)}
    )


if __name__ == "__main__":
    import uvicorn
    # Start without reload to keep the process running when launched via `python main.py`.
    # If you want auto-reload during development, run: python -m uvicorn main:app --reload
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=False)