# 🥚 Egg Production Prediction System

Polutry Sighat is Aamachine learning-powered FastAPI application that predicts egg production based on environmental factors in poultry farms. This system uses a deep learning model trained on real farm data to help optimize production conditions.

![Python](https://img.shields.io/badge/Python-3.9+-blue.svg)
![TensorFlow](https://img.shields.io/badge/TensorFlow-2.15.0-orange.svg)
![FastAPI](https://img.shields.io/badge/FastAPI-0.104.1-green.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## 📋 Table of Contents

- [Features](#features)
- [System Architecture](#system-architecture)
- [Installation](#installation)
- [Usage](#usage)
- [API Documentation](#api-documentation)
- [Model Information](#model-information)
- [Project Structure](#project-structure)
- [Development](#development)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## ✨ Features

- **Real-time Predictions**: Get instant egg production forecasts based on environmental parameters
- **Batch Processing**: Process multiple farm predictions simultaneously (up to 100 farms)
- **Smart Recommendations**: Receive actionable insights to optimize farm conditions
- **RESTful API**: Easy integration with web and mobile applications
- **Interactive Documentation**: Built-in Swagger UI and ReDoc for API exploration
- **Health Monitoring**: Comprehensive health checks and diagnostics
- **CORS Support**: Ready for cross-origin requests from web applications

## 🏗️ System Architecture

The system consists of three main components:

1. **Deep Learning Model**: A Sequential Neural Network trained on historical egg production data
2. **FastAPI Backend**: RESTful API server handling predictions and recommendations
3. **Data Processing Pipeline**: StandardScaler for feature normalization

### Model Architecture

```
Input Layer (5 features)
    ↓
Dense Layer (64 neurons, ReLU)
    ↓
Dropout (0.5)
    ↓
Dense Layer (32 neurons, ReLU)
    ↓
Dropout (0.5)
    ↓
Dense Layer (16 neurons, ReLU)
    ↓
Dense Layer (8 neurons, ReLU)
    ↓
Output Layer (1 neuron)
```

### Input Features

The model requires 5 environmental parameters:

| Feature | Description | Range | Optimal Range |
|---------|-------------|-------|---------------|
| **Amount of Chicken** | Number of chickens in the farm | 100-10,000 | - |
| **Ammonia** | Ammonia level in parts per million (ppm) | 0-100 | < 15 ppm |
| **Temperature** | Temperature in Celsius | -10 to 50°C | 18-28°C |
| **Humidity** | Relative humidity percentage | 0-100% | 50-70% |
| **Light Intensity** | Light intensity in lux | 0-10,000 | 200-500 lux |

## 🚀 Installation

### Prerequisites

- Python 3.9 or higher
- pip (Python package manager)
- Virtual environment (recommended)

### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd "Project Capstone"
```

### Step 2: Create Virtual Environment

```bash
# Windows
python -m venv .venv
.venv\Scripts\activate

# Linux/Mac
python3 -m venv .venv
source .venv/bin/activate
```

### Step 3: Install Dependencies

```bash
pip install -r requirements.txt
```

### Step 4: Verify Installation

```bash
python -c "import tensorflow; import fastapi; print('✅ All dependencies installed successfully')"
```

## 💻 Usage

### Starting the Server

#### Option 1: Using Python directly

```bash
python main.py
```

#### Option 2: Using Uvicorn

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The API will be available at:
- **API Base URL**: http://localhost:8000
- **Interactive Docs (Swagger)**: http://localhost:8000/docs
- **Alternative Docs (ReDoc)**: http://localhost:8000/redoc

### Making Predictions

#### Using cURL

```bash
curl -X POST "http://localhost:8000/predict" \
  -H "Content-Type: application/json" \
  -d '{
    "amount_of_chicken": 2728.0,
    "ammonia": 14.4,
    "temperature": 29.3,
    "humidity": 51.7,
    "light_intensity": 364.0
  }'
```

#### Using Python Requests

```python
import requests

url = "http://localhost:8000/predict"
data = {
    "amount_of_chicken": 2728.0,
    "ammonia": 14.4,
    "temperature": 29.3,
    "humidity": 51.7,
    "light_intensity": 364.0
}

response = requests.post(url, json=data)
print(response.json())
```

#### Using JavaScript (Fetch API)

```javascript
fetch('http://localhost:8000/predict', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    amount_of_chicken: 2728.0,
    ammonia: 14.4,
    temperature: 29.3,
    humidity: 51.7,
    light_intensity: 364.0
  })
})
.then(response => response.json())
.then(data => console.log(data));
```

## 📚 API Documentation

### Endpoints

#### 1. Health Check

```http
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "model_loaded": true,
  "scaler_X_loaded": true,
  "last_error": null,
  "timestamp": "2024-01-15T10:30:00",
  "version": "1.0.0"
}
```

#### 2. Single Prediction

```http
POST /predict
```

**Request Body:**
```json
{
  "amount_of_chicken": 2728.0,
  "ammonia": 14.4,
  "temperature": 29.3,
  "humidity": 51.7,
  "light_intensity": 364.0
}
```

**Response:**
```json
{
  "predicted_egg_production": 902.93,
  "confidence_score": 0.85,
  "farm_size_category": "Large Farm",
  "recommendations": [
    "✅ Temperature is optimal",
    "✅ Humidity is optimal",
    "✅ Ammonia levels are safe",
    "✅ Light intensity is optimal"
  ],
  "timestamp": "2024-01-15T10:30:00",
  "model_version": "1.0.0",
  "input_data": {
    "amount_of_chicken": 2728.0,
    "ammonia": 14.4,
    "temperature": 29.3,
    "humidity": 51.7,
    "light_intensity": 364.0
  }
}
```

#### 3. Batch Prediction

```http
POST /predict/batch
```

**Request Body:**
```json
{
  "farms": [
    {
      "amount_of_chicken": 2728.0,
      "ammonia": 14.4,
      "temperature": 29.3,
      "humidity": 51.7,
      "light_intensity": 364.0
    },
    {
      "amount_of_chicken": 1500.0,
      "ammonia": 18.0,
      "temperature": 25.0,
      "humidity": 60.0,
      "light_intensity": 300.0
    }
  ]
}
```

**Response:**
```json
{
  "predictions": [...],
  "total_predictions": 2,
  "timestamp": "2024-01-15T10:30:00"
}
```

#### 4. Model Information

```http
GET /model/info
```

**Response:**
```json
{
  "model_type": "Sequential Neural Network",
  "input_features": 5,
  "output_features": 1,
  "model_version": "1.0.0",
  "training_date": "2024-01-01",
  "features": [
    "amount_of_chicken",
    "ammonia",
    "temperature",
    "humidity",
    "light_intensity"
  ]
}
```

## 🧠 Model Information

### Training Details

- **Dataset**: Egg_Production(1).csv (historical farm data)
- **Training Framework**: TensorFlow/Keras 2.15.0
- **Model Type**: Deep Neural Network (Sequential)
- **Loss Function**: Mean Squared Error (MSE)
- **Optimizer**: Adam
- **Regularization**: Dropout layers (0.5)

### Performance Metrics

The model has been trained and validated on real farm data with the following characteristics:
- Input features are standardized using StandardScaler
- Output predictions are in actual egg production units (no inverse scaling needed)
- Model includes dropout layers to prevent overfitting

### Model Files

- `sequence_model_fixed.h5`: TensorFlow 2.10.0 compatible model (primary)
- `sequence_model.h5`: Original model file
- `scaler_X.pkl`: Feature scaler (StandardScaler)

## 📁 Project Structure

```
Project Capstone/
├── main.py                          # FastAPI application
├── requirements.txt                 # Python dependencies
├── README.md                        # This file
├── Egg_Production(1).csv           # Training dataset
├── Capstone_NoteBook_Updated.ipynb # Jupyter notebook for model training
├── models/                         # Model and scaler files
│   ├── sequence_model_fixed.h5    # Compatible model file
│   ├── sequence_model.h5          # Original model file
│   ├── sequence_model.keras       # Keras format model
│   └── scaler_X.pkl               # Feature scaler
├── Circuit-Diagram/               # Hardware circuit diagrams
│   └── Circuit Diagram.png
└── .venv/                         # Virtual environment (not in git)
```

## 🛠️ Development

### Running Tests

```bash
# Test model loading
python -c "from main import load_model; load_model()"

# Test prediction endpoint
python -c "import requests; print(requests.post('http://localhost:8000/predict', json={'amount_of_chicken': 2728, 'ammonia': 14.4, 'temperature': 29.3, 'humidity': 51.7, 'light_intensity': 364.0}).json())"
```

### Environment Variables

You can customize the application using environment variables:

```bash
# Set custom model path
export MODEL_PATH="path/to/your/model.h5"

# Set custom scaler path
export SCALER_X_PATH="path/to/your/scaler.pkl"
```

### Development Mode

For development with auto-reload:

```bash
uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Model Loading Error: "Unrecognized keyword arguments: ['batch_shape']"

**Solution**: Use the `sequence_model_fixed.h5` file which is compatible with TensorFlow 2.10.0+

```bash
# Verify the fixed model exists
ls models/sequence_model_fixed.h5
```

#### 2. Scaler Loading Error: "No module named 'numpy._core'"

**Solution**: Regenerate the scaler with your current NumPy version

```python
import pandas as pd
import joblib
from sklearn.preprocessing import StandardScaler

# Load training data
df = pd.read_csv('Egg_Production(1).csv')
features = ['Amount_of_chicken', 'Ammonia', 'Temperature', 'Humidity', 'Light_Intensity']
X = df[features].values

# Fit and save scaler
scaler = StandardScaler()
scaler.fit(X)
joblib.dump(scaler, 'models/scaler_X.pkl')
print("✅ Scaler regenerated successfully")
```

#### 3. CUDA/GPU Warnings

These warnings are normal if you don't have a GPU:
```
Could not load dynamic library 'cudart64_110.dll'
```

The model will run on CPU automatically. To suppress warnings:

```python
import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'
```

#### 4. Port Already in Use

```bash
# Windows
netstat -ano | findstr :8000
taskkill /PID <PID> /F

# Linux/Mac
lsof -ti:8000 | xargs kill -9
```

### Logging

The application uses Python's logging module. To increase verbosity:

```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Code Style

- Follow PEP 8 guidelines
- Use type hints where possible
- Add docstrings to functions and classes
- Write meaningful commit messages

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👥 Authors

- **Kyla** - *Initial work and development*

## 🙏 Acknowledgments

- TensorFlow team for the deep learning framework
- FastAPI team for the excellent web framework
- scikit-learn for preprocessing tools
- All contributors and testers

## 📞 Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Check the [API Documentation](http://localhost:8000/docs) when the server is running
- Review the troubleshooting section above

## 🔮 Future Enhancements

- [ ] Add authentication and API key management
- [ ] Implement data persistence with database
- [ ] Add historical prediction tracking
- [ ] Create web dashboard for visualization
- [ ] Implement A/B testing for model versions
- [ ] Add support for more environmental factors
- [ ] Integrate with IoT sensors for real-time monitoring
- [ ] Add email/SMS alerts for critical conditions

---

**Made with ❤️ for sustainable poultry farming**#   C a p s t o n e P r o j e c t  
 