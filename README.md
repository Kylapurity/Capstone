# 🥚 Poultry Management System

**🥚Poultry Sight** is a **machine learning-powered application** that predicts egg production based on environmental factors in poultry farms.
This system uses a **Traditional Model** trained on real farm data to help farmers **optimise egg production** and **analyze enviromental factors**.

---
## 🎥 Final Version video and APK File

https://drive.google.com/drive/folders/19_aHnFVATZZzpTgOyjm5zBDBGoueEU_d?usp=sharing

## ✨ Features

* ⚡ **Real-time Predictions** — Get instant egg production forecasts based on environmental parameters.
* 🧮 **Batch Processing** — Process multiple farm predictions simultaneously (up to 100 farms).
* 💡 **Smart Recommendations** — Receive actionable insights to optimize poultry conditions.
* 🌐 **Fast API** — Seamlessly integrates with our mobile app.
* 🧭 **Interactive Documentation** — Swagger UI and ReDoc included for easy API exploration.
* 🩺 **Health Monitoring** — System diagnostics and health checks.
* 🔒 **CORS Enabled** — Ready for cross-origin requests from web applications.

---

## 🏗️ System Architecture

The system includes three main components:

1. **Deep Learning Model** — Sequential neural network trained on historical egg production data.
2. **FastAPI Backend** — RESTful API server for predictions and recommendations.
3. **Data Processing Pipeline** — Uses `StandardScaler` for input normalization.

---

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

---

### 🌡️ Input Features

| Feature               | Description                    | Range      | Optimal Range |
| --------------------- | ------------------------------ | ---------- | ------------- |
| **Amount of Chicken** | Number of chickens on the farm | 100–10,000 | —             |
| **Ammonia**           | Ammonia level (ppm)            | 0–100      | < 15 ppm      |
| **Temperature**       | Temperature (°C)               | -10–50°C   | 18–28°C       |
| **Humidity**          | Relative humidity (%)          | 0–100%     | 50–70%        |
| **Light Intensity**   | Light level (lux)              | 0–10,000   | 200–500 lux   |
| **Noise**             | Sound level (dB)               | 0–120 dB   | Optimal <60 dB|
| **Amount of Feeding** | Feed amount per session (grams) | 0–2000 g   | 900 g         |

---

## 🧪 Model Comparison and Performance

|      **Model**     |  **Train MSE** |  **Test MSE**  | **Train R²** | **Test R²** | **Train MAE** | **Test MAE** |
| :----------------: | :------------: | :------------: | :----------: | :---------: | :-----------: | :----------: |
|       XGBoost      |   25555.5938   |   48045.9961   |    0.8987    |    0.8554   |    88.9186    |   101.4593   |
|         SVM        |   58246.8922   |   101518.1984  |    0.7690    |    0.6944   |    74.8217    |    92.1558   |
|    Decision Tree   |   25986.2391   |   49358.5858   |    0.8970    |    0.8514   |    58.4187    |    82.2943   |
|    Random Forest   |   14106.5453   |   28853.3894   |    0.9441    |    0.9131   |    43.1793    |    61.1087   |
| **multilayer Perceptron (MLP)** | **25457.4023** | **25202.7207** |  **0.8991**  |  **0.9241** |  **70.7075**  |  **67.8767** |

🏆 **Best Model:** Sequence Model

* **Test R²:** 0.9241
* **Test MSE:** 25202.72
* **Test MAE:** 67.88

📊 **Model Ranking (by Test R²):**

1. Multilayer Perceptron (MLP) model — R² = 0.9241
2. Random Forest — R² = 0.9131
3. XGBoost — R² = 0.8554
4. Decision Tree — R² = 0.8514
5. SVM — R² = 0.6944

---

## ⚙️ Component Testing Outputs

| Test Case | Component         | Requirement                              | Expected Output                                         | Actual Result                                               | Test Result |
| ---------- | ---------------- | ---------------------------------------- | ------------------------------------------------------- | ----------------------------------------------------------- | ------------ |
| 1 | DHT22 Sensor | Measure temperature and humidity accurately | Readings within ±0.5°C / ±2% RH | Sensor provided consistent readings within specified tolerance | Passed |
| 2 | MQ-135 Gas Sensor | Detect CO₂ levels in poultry environment | Analog values corresponding to 400–5000 ppm range | Output varied accurately with air quality changes | Passed |
| 3 | MQ-137 Sensor | Measure ammonia concentration | Reliable detection of 10–300 ppm NH₃ | Sensor responded correctly to ammonia presence | Passed |
| 4 | LDR Sensor | Monitor light intensity in poultry house | Analog values reflecting 0–1000 lux range | Readings matched external lux meter measurements | Passed |
| 5 | ESP32 Wi-Fi Module | Establish stable internet connection | Successful connection and HTTP POST to cloud API | Device maintained stable connection and transmitted data | Passed |
| 6 | Data Processing Logic | Format sensor data into JSON payload | Correctly structured JSON with all sensor values | API successfully parsed and stored all data fields | Passed |
| 7 | Breadboard Circuit | Provide stable electrical connections | Consistent power and signal transmission | All sensors maintained stable connections without signal loss | Passed |
| 8 | TensorFlow Lite Model | Generate offline predictions | Production forecasts without internet connection | Model provided predictions with 82% accuracy offline | Passed |

---
## 🎨 Figma Design

You can view the **system interface design** here:
👉 [View Figma Design](https://www.figma.com/proto/jZ9OURmQohfBnr9YyHeO29/Purity-_Kihiu_Capstone-Project?node-id=3-10&p=f&t=uFV1209lRIZZQlFI-0&scaling=scale-down&content-scaling=fixed&page-id=0%3A1&starting-point-node-id=3%3A10)

---

### 🔹 Swagger API

[https://capstone-trt6.onrender.com/predict](https://capstone-trt6.onrender.com/docs#/)
---

#### 🖼️ Poultry App Screenshots

<p align="center">
  <img src="https://github.com/user-attachments/assets/983c26bb-5d4d-4a67-9795-839312ba11db" width="300" alt="Poultry App Screenshot 1"/>
  <img src="https://github.com/user-attachments/assets/38c84267-3abc-42c2-ad95-79ffdf61af96" width="300" alt="Poultry App Screenshot 2"/>
  <img src="https://github.com/user-attachments/assets/d9cb6887-c171-4360-993e-679fbaa1439d" width="300" alt="Poultry App Screenshot 3"/>
  <img src="https://github.com/user-attachments/assets/2b33645b-a730-49c4-ae2b-0ce5628572b6" width="300" alt="Poultry App Screenshot 4"/>
  <img src="https://github.com/user-attachments/assets/c72a41e4-02cc-4c1c-91d7-97ad3346b12a" width="300" alt="Poultry App Screenshot 5"/>
  <img src="https://github.com/user-attachments/assets/f8a16e0a-2a52-4e79-b8a7-552be88471ca" width="300" alt="Poultry App Screenshot 6"/>
  <img src="https://github.com/user-attachments/assets/be854ea2-0b7f-4a3c-b593-48ddbf27d8a0" width="300" alt="Poultry App Screenshot 7"/>
</p>

---

## 🎥 Intial Video Demo

https://drive.google.com/drive/folders/1kOHgdyzWdpjWVaDbUydlGXtKXq6h9sAR?usp=drive_link

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

Start the FastAPI server and make predictions using Python, JavaScript, or cURL commands.
(API and code usage sections remain as in your original README — unchanged for clarity.)

---

## 🧠 Model Information

* **Dataset:** Egg_Production(1).csv
* **Framework:** TensorFlow/Keras 2.15.0
* **Model Type:** Sequential Deep Neural Network
* **Loss Function:** MSE
* **Optimizer:** Adam
* **Regularization:** Dropout (0.5)

---

## 📁 Project Structure

```
Project Capstone/
├── main.py
├── requirements.txt
├── README.md
├── Egg_Production(1).csv
├── Notebook/
    ├── Capstone_notebooke_Updated
├── models/
│   ├── sequence_model_fixed.h5
│   ├── sequence_model.h5
│   ├── sequence_model.keras
│   └── scaler_X.pkl
├── Circuit-Diagram/
│   └── Circuit Diagram.png
└── .venv/
```

## 📄 License

Licensed under the **MIT License** — see the `LICENSE` file for details.

---

## 👥 Authors

**Purity Kihiu** — *Project Design, Development, and Model Optimization*

---

## 🙏 Acknowledgments
* All contributors and testers
---













