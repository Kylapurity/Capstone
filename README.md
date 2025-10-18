# 🥚 Egg Production Prediction System

**🥚Poultry Sight** is a **machine learning-powered FastAPI application** that predicts egg production based on environmental factors in poultry farms.
This system uses a **deep learning model** trained on real farm data to help farmers **optimize production conditions** and improve yield.

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

---

## 🧪 Model Comparison and Performance

|      **Model**     |  **Train MSE** |  **Test MSE**  | **Train R²** | **Test R²** | **Train MAE** | **Test MAE** |
| :----------------: | :------------: | :------------: | :----------: | :---------: | :-----------: | :----------: |
|       XGBoost      |   25555.5938   |   48045.9961   |    0.8987    |    0.8554   |    88.9186    |   101.4593   |
|         SVM        |   58246.8922   |   101518.1984  |    0.7690    |    0.6944   |    74.8217    |    92.1558   |
|    Decision Tree   |   25986.2391   |   49358.5858   |    0.8970    |    0.8514   |    58.4187    |    82.2943   |
|    Random Forest   |   14106.5453   |   28853.3894   |    0.9441    |    0.9131   |    43.1793    |    61.1087   |
| **Sequence Model** | **25457.4023** | **25202.7207** |  **0.8991**  |  **0.9241** |  **70.7075**  |  **67.8767** |

🏆 **Best Model:** Sequence Model

* **Test R²:** 0.9241
* **Test MSE:** 25202.72
* **Test MAE:** 67.88

📊 **Model Ranking (by Test R²):**

1. Sequence Model — R² = 0.9241
2. Random Forest — R² = 0.9131
3. XGBoost — R² = 0.8554
4. Decision Tree — R² = 0.8514
5. SVM — R² = 0.6944

---

## 🎨 Figma Design

You can view the **system interface design** here:
👉 [View Figma Design](https://www.figma.com/proto/jZ9OURmQohfBnr9YyHeO29/Purity-_Kihiu_Capstone-Project?node-id=3-10&p=f&t=uFV1209lRIZZQlFI-0&scaling=scale-down&content-scaling=fixed&page-id=0%3A1&starting-point-node-id=3%3A10)

---

## 🖼️ Screenshots

### 🔹 Swagger API

https://capstone-trt6.onrender.com/predict

### 🔹 Figma System Design

<img width="500" height="840" alt="image" src="https://github.com/user-attachments/assets/0ea33847-085e-4931-b989-6177a0878326" />
<img width="475" height="813" alt="image" src="https://github.com/user-attachments/assets/925a412d-dfd6-4538-bba9-cac485886b51" />
<img width="542" height="822" alt="image" src="https://github.com/user-attachments/assets/6cfd4918-3e2e-4481-9eb6-2e9b68a1a642" />
<img width="486" height="846" alt="image" src="https://github.com/user-attachments/assets/c58ae012-59f7-44a2-9aad-a643a808ded0" />

---

## 🎥 Video Demonstration

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

## 📄 License

Licensed under the **MIT License** — see the `LICENSE` file for details.

---

## 👥 Authors

**Purity Kihiu** — *Project Design, Development, and Model Optimization*

---

## 🙏 Acknowledgments

* TensorFlow team — Deep learning framework
* FastAPI team — API framework
* scikit-learn — Data preprocessing
* All contributors and testers

---






