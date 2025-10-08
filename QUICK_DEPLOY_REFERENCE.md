# ⚡ Quick Deploy Reference - Render

## 🔧 What Was Fixed

### ❌ The Problem
```
ERROR: Could not find a version that satisfies the requirement tensorflow==2.15.0
```

### ✅ The Solution
Updated `requirements.txt`:
- Changed: `tensorflow==2.15.0` 
- To: `tensorflow>=2.16.0,<2.21.0`
- Added: `h5py>=3.10.0` and `protobuf>=3.20.0,<5.0.0`

---

## 🚀 Deploy in 3 Steps

### Step 1: Commit Changes
```powershell
git add .
git commit -m "Fix TensorFlow version for Render deployment"
git push origin main
```

### Step 2: Create Render Service
1. Go to https://dashboard.render.com/
2. Click "New +" → "Web Service"
3. Connect your GitHub repository
4. Use these settings:
   - **Build Command:** `pip install --upgrade pip && pip install -r requirements.txt`
   - **Start Command:** `uvicorn main:app --host 0.0.0.0 --port $PORT`

### Step 3: Set Environment Variables
Add in Render dashboard:
```
PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION = python
MODEL_PATH = ./models/sequence_model_fixed.h5
SCALER_X_PATH = ./models/scaler_X.pkl
```

---

## 🧪 Test Your Deployment

### Health Check
```
https://your-app.onrender.com/health
```

### API Docs
```
https://your-app.onrender.com/docs
```

### Test Prediction
```bash
curl -X POST https://your-app.onrender.com/predict \
  -H "Content-Type: application/json" \
  -d '{"amount_of_chicken": 2728, "ammonia": 14.4, "temperature": 29.3, "humidity": 51.7, "light_intensity": 364}'
```

---

## 💡 Important Notes

- ✅ **Model files MUST be in Git** (they're needed for deployment)
- ✅ **Free tier spins down** after 15min inactivity (first request takes ~30s)
- ✅ **Starter plan ($7/mo)** recommended for always-on service
- ✅ **Build takes 5-10 minutes** (TensorFlow is large)

---

## 🆘 If Build Fails

1. Check Render logs for specific error
2. Verify model files are committed: `git ls-files models/`
3. Ensure Python 3.11 is specified in `runtime.txt`
4. Try upgrading to Starter plan (more memory)

---

## 📁 Files Created/Updated

- ✅ `requirements.txt` - Updated TensorFlow version
- ✅ `runtime.txt` - Python version specification
- ✅ `render.yaml` - Render configuration
- ✅ `Procfile` - Alternative start command
- ✅ `.gitignore` - Ensures models aren't ignored
- ✅ `RENDER_DEPLOYMENT_GUIDE.md` - Full guide
- ✅ `QUICK_DEPLOY_REFERENCE.md` - This file

---

## 🎯 Your Next Action

Run these commands NOW:
```powershell
git add .
git commit -m "Prepare for Render deployment - fix TensorFlow version"
git push origin main
```

Then go to: https://dashboard.render.com/ and deploy! 🚀