Here’s your **cleaned and professionally fixed version** of the README file — corrected for grammar, clarity, and structure while keeping all your technical details intact.

---

# 🥚 Egg Production Prediction System

**Poultry Sight** is a **machine learning-powered FastAPI application** that predicts egg production based on environmental factors in poultry farms.
This system uses a **deep learning model** trained on real farm data to help farmers **optimize production conditions** and improve yield.

![Python](https://img.shields.io/badge/Python-3.9+-blue.svg)
![TensorFlow](https://img.shields.io/badge/TensorFlow-2.15.0-orange.svg)
![FastAPI](https://img.shields.io/badge/FastAPI-0.104.1-green.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

---

## 📋 Table of Contents

* [Features](#features)
* [System Architecture](#system-architecture)
* [Installation](#installation)
* [Usage](#usage)
* [API Documentation](#api-documentation)
* [Model Information](#model-information)
* [Project Structure](#project-structure)
* [Development](#development)
* [Troubleshooting](#troubleshooting)
* [Contributing](#contributing)
* [License](#license)
* [Authors](#authors)
* [Acknowledgments](#acknowledgments)
* [Support](#support)
* [Future Enhancements](#future-enhancements)

---

## ✨ Features

* ⚡ **Real-time Predictions** — Get instant egg production forecasts based on environmental parameters.
* 🧮 **Batch Processing** — Process multiple farm predictions simultaneously (up to 100 farms).
* 💡 **Smart Recommendations** — Receive actionable insights to optimize poultry conditions.
* 🌐 **RESTful API** — Seamlessly integrate with web or mobile apps.
* 🧭 **Interactive Documentation** — Swagger UI and ReDoc included for easy API exploration.
* 🩺 **Health Monitoring** — System diagnostics and health checks.
* 🔒 **CORS Enabled** — Ready for cross-origin requests from web applications.

---

## 🏗️ System Architecture

The system includes three main components:

1. **Deep Learning Model** — Sequential neural network trained on historical egg production data.
2. **FastAPI Backend** — RESTful API server for predictions and recommendations.
3. **Data Processing Pipeline** — Uses `StandardScaler` for input normalization.

### 🧠 Model Architecture

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

### 🌡️ Input Features

| Feature               | Description                    | Range      | Optimal Range |
| --------------------- | ------------------------------ | ---------- | ------------- |
| **Amount of Chicken** | Number of chickens on the farm | 100–10,000 | —             |
| **Ammonia**           | Ammonia level (ppm)            | 0–100      | < 15 ppm      |
| **Temperature**       | Temperature (°C)               | -10–50°C   | 18–28°C       |
| **Humidity**          | Relative humidity (%)          | 0–100%     | 50–70%        |
| **Light Intensity**   | Light level (lux)              | 0–10,000   | 200–500 lux   |

---

## 🚀 Installation

### Prerequisites

* Python 3.9 or higher
* pip (Python package manager)
* Virtual environment (recommended)

### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd "Capstone"
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

---

## 💻 Usage

### Starting the Server

#### Option 1: Using Python

```bash
python main.py
```

#### Option 2: Using Uvicorn

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

**API URLs:**

* Swagger Docs → [http://localhost:8000/docs](http://localhost:8000/docs)
* ReDoc → [http://localhost:8000/redoc](http://localhost:8000/redoc)

---

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

#### Using Python

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

#### Using JavaScript

```javascript
fetch('http://localhost:8000/predict', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    amount_of_chicken: 2728.0,
    ammonia: 14.4,
    temperature: 29.3,
    humidity: 51.7,
    light_intensity: 364.0
  })
})
.then(res => res.json())
.then(data => console.log(data));
```

---

## 📚 API Documentation

### Endpoints Overview

| Endpoint         | Method | Description                    |
| ---------------- | ------ | ------------------------------ |
| `/health`        | GET    | Health check and system status |
| `/predict`       | POST   | Single prediction request      |
| `/predict/batch` | POST   | Multiple predictions at once   |
| `/model/info`    | GET    | Returns model metadata         |

Example responses are included in the original version and remain unchanged.

---

## 🧠 Model Information

### Training Details

* **Dataset:** Egg_Production(1).csv (historical farm data)
* **Framework:** TensorFlow/Keras 2.15.0
* **Model Type:** Deep Neural Network (Sequential)
* **Loss Function:** Mean Squared Error (MSE)
* **Optimizer:** Adam
* **Regularization:** Dropout layers (0.5)

### Model Files

* `sequence_model_fixed.h5` — Optimized model for TensorFlow 2.10+
* `sequence_model.h5` — Original model
* `scaler_X.pkl` — Feature scaler (StandardScaler)

---

## 📁 Project Structure

```
Project Capstone/
├── main.py
├── requirements.txt
├── README.md
├── Egg_Production(1).csv
├── Capstone_NoteBook_Updated.ipynb
├── models/
│   ├── sequence_model_fixed.h5
│   ├── sequence_model.h5
│   ├── sequence_model.keras
│   └── scaler_X.pkl
├── Circuit-Diagram/
│   └── Circuit Diagram.png
└── .venv/
```

---

## 🛠️ Development

### Testing

```bash
# Model loading test
python -c "from main import load_model; load_model()"

# API test
python -c "import requests; print(requests.post('http://localhost:8000/predict', json={'amount_of_chicken':2728,'ammonia':14.4,'temperature':29.3,'humidity':51.7,'light_intensity':364.0}).json())"
```

### Environment Variables

```bash
export MODEL_PATH="path/to/your/model.h5"
export SCALER_X_PATH="path/to/your/scaler.pkl"
```

### Development Mode

```bash
uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

---

## 🔧 Troubleshooting

Common issues and their solutions are kept intact (model loading, scaler errors, GPU warnings, and port conflicts).

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add new feature'`)
4. Push and open a Pull Request

### Code Style

* Follow **PEP 8** standards
* Use **type hints** and **docstrings**
* Write meaningful **commit messages**

---

## 📄 License

This project is licensed under the **MIT License** — see the `LICENSE` file for details.

---

## 👥 Authors

* **Kyla** — *Initial work and development*

---

## 🙏 Acknowledgments

* TensorFlow team — Deep learning framework
* FastAPI team — API framework
* scikit-learn — Data preprocessing
* All contributors and testers

---
