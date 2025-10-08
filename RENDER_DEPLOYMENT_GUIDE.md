# 🚀 Render Deployment Guide for Poultry Sight API

## ✅ Files Updated for Deployment

### 1. **requirements.txt** (UPDATED)
- ✅ Changed `tensorflow==2.15.0` to `tensorflow>=2.16.0,<2.21.0` (flexible version)
- ✅ Added `h5py>=3.10.0` for model loading
- ✅ Added `protobuf>=3.20.0,<5.0.0` for TensorFlow compatibility
- ✅ Made other packages more flexible with version ranges

### 2. **runtime.txt** (NEW)
- Specifies Python 3.11.9 for Render

### 3. **render.yaml** (NEW)
- Complete Render configuration
- Sets environment variables
- Configures build and start commands

### 4. **Procfile** (NEW)
- Alternative start command configuration

### 5. **.gitignore** (NEW)
- Ensures model files are NOT ignored (they're needed!)

---

## 📋 Pre-Deployment Checklist

### ✅ Verify Model Files Exist
Make sure these files are in your repository:
```
models/
├── sequence_model_fixed.h5 (or sequence_model.h5)
└── scaler_X.pkl
```

### ✅ Commit All Changes to Git
```powershell
git add .
git commit -m "Update dependencies for Render deployment"
git push origin main
```

---

## 🌐 Render Deployment Steps

### Option 1: Deploy via Render Dashboard (Recommended)

1. **Go to Render Dashboard**
   - Visit: https://dashboard.render.com/

2. **Create New Web Service**
   - Click "New +" → "Web Service"

3. **Connect Your Repository**
   - Connect your GitHub/GitLab account
   - Select your `projectcap` repository

4. **Configure Service Settings**
   ```
   Name: poultry-sight-api
   Region: Choose closest to your users
   Branch: main
   Runtime: Python 3
   Build Command: pip install --upgrade pip && pip install -r requirements.txt
   Start Command: uvicorn main:app --host 0.0.0.0 --port $PORT
   ```

5. **Set Environment Variables**
   Add these in the "Environment" section:
   ```
   PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION = python
   MODEL_PATH = ./models/sequence_model_fixed.h5
   SCALER_X_PATH = ./models/scaler_X.pkl
   ```

6. **Choose Instance Type**
   - **Free Tier**: Good for testing (spins down after inactivity)
   - **Starter ($7/month)**: Recommended for production (always on)

7. **Deploy!**
   - Click "Create Web Service"
   - Wait 5-10 minutes for build to complete

---

### Option 2: Deploy via render.yaml (Infrastructure as Code)

1. **Push render.yaml to your repository**
   ```powershell
   git add render.yaml
   git commit -m "Add Render configuration"
   git push origin main
   ```

2. **Create Blueprint in Render**
   - Go to Render Dashboard
   - Click "New +" → "Blueprint"
   - Select your repository
   - Render will automatically detect `render.yaml`
   - Click "Apply"

---

## 🔍 Troubleshooting Common Issues

### Issue 1: TensorFlow Installation Fails
**Error:** `ERROR: No matching distribution found for tensorflow==2.15.0`

**Solution:** ✅ Already fixed! We updated to `tensorflow>=2.16.0,<2.21.0`

---

### Issue 2: Model File Not Found
**Error:** `FileNotFoundError: Model file not found`

**Solution:**
1. Verify model files are committed to Git:
   ```powershell
   git ls-files models/
   ```
2. If missing, add them:
   ```powershell
   git add models/sequence_model_fixed.h5 models/scaler_X.pkl
   git commit -m "Add model files"
   git push
   ```

---

### Issue 3: Build Timeout
**Error:** `Build exceeded time limit`

**Solution:**
- Render free tier has build time limits
- Upgrade to Starter plan ($7/month)
- Or optimize requirements.txt (remove unused packages)

---

### Issue 4: Memory Issues During Build
**Error:** `Killed` or `Out of memory`

**Solution:**
- TensorFlow is memory-intensive
- Upgrade to at least **Starter plan** (512MB RAM minimum)
- Free tier (512MB) might struggle with TensorFlow

---

### Issue 5: Health Check Fails
**Error:** `Health check failed`

**Solution:**
1. Check logs in Render dashboard
2. Verify `/health` endpoint works:
   ```
   https://your-app.onrender.com/health
   ```
3. Ensure model loads successfully (check startup logs)

---

## 🧪 Testing Your Deployment

### 1. Check Health Endpoint
```bash
curl https://your-app.onrender.com/health
```

Expected response:
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

### 2. Test Prediction Endpoint
```bash
curl -X POST https://your-app.onrender.com/predict \
  -H "Content-Type: application/json" \
  -d '{
    "amount_of_chicken": 2728.0,
    "ammonia": 14.4,
    "temperature": 29.3,
    "humidity": 51.7,
    "light_intensity": 364.0
  }'
```

### 3. Access API Documentation
Visit: `https://your-app.onrender.com/docs`

---

## 💰 Render Pricing

| Plan | Price | RAM | CPU | Features |
|------|-------|-----|-----|----------|
| **Free** | $0 | 512MB | 0.1 CPU | Spins down after 15min inactivity |
| **Starter** | $7/mo | 512MB | 0.5 CPU | Always on, custom domains |
| **Standard** | $25/mo | 2GB | 1 CPU | Better performance |
| **Pro** | $85/mo | 4GB | 2 CPU | Production-grade |

**Recommendation:** Start with **Starter plan** ($7/month) for reliable performance.

---

## 🔐 Security Best Practices

### 1. Add API Key Authentication (Optional)
Update `main.py` to require API keys for production.

### 2. Set CORS Origins
In `main.py`, change:
```python
allow_origins=["*"]  # Development
```
To:
```python
allow_origins=["https://your-frontend-domain.com"]  # Production
```

### 3. Enable HTTPS
Render provides free SSL certificates automatically! ✅

---

## 📊 Monitoring Your Deployment

### View Logs
1. Go to Render Dashboard
2. Select your service
3. Click "Logs" tab
4. Monitor real-time logs

### Set Up Alerts
1. Go to "Settings" → "Notifications"
2. Add email/Slack for deployment failures
3. Set up health check alerts

---

## 🎯 Next Steps After Deployment

1. ✅ Test all endpoints thoroughly
2. ✅ Update your frontend to use the new API URL
3. ✅ Set up monitoring and alerts
4. ✅ Document your API URL for your capstone report
5. ✅ Consider adding rate limiting for production

---

## 📞 Need Help?

- **Render Docs:** https://render.com/docs
- **Render Community:** https://community.render.com/
- **FastAPI Docs:** https://fastapi.tiangolo.com/deployment/

---

## ✅ Deployment Checklist

- [ ] Updated `requirements.txt` with compatible TensorFlow version
- [ ] Created `runtime.txt` with Python version
- [ ] Created `render.yaml` configuration
- [ ] Verified model files exist in `models/` directory
- [ ] Committed all changes to Git
- [ ] Pushed to GitHub/GitLab
- [ ] Created Render account
- [ ] Connected repository to Render
- [ ] Configured environment variables
- [ ] Deployed service
- [ ] Tested `/health` endpoint
- [ ] Tested `/predict` endpoint
- [ ] Verified API documentation at `/docs`
- [ ] Updated frontend with new API URL

---

## 🎉 Success!

Once deployed, your API will be available at:
```
https://poultry-sight-api.onrender.com
```

You can now use this URL in your frontend application and capstone presentation! 🚀