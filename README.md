# 📱🌿 Silkreto Mobile Application

Hello, Good Day! 👋

This repository contains the source code and documentation for the **Silkreto Mobile Application**, a mobile-based system designed for the **image-based detection and monitoring of silkworm larvae**.

The application allows users to capture or upload an image, detect silkworm larvae, classify them as **Healthy (`H`)** or **Unhealthy (`UH`)**, display bounding boxes, show risk-based tips and recommendations, and save scan results locally for future review.

This repository serves as the documentation and codebase of the mobile application component of the **Silkreto** project for development, academic reference, and future improvement.

---

## ✨ Features

- 📷 **Image Input**  
  Users can analyze silkworm images through:
  - **Scan** – capture an image using the device camera
  - **Upload** – select an image from the device gallery

- ✂️ **Image Cropping**  
  Selected images can be cropped into a square format before analysis.

- 🧠 **Image Analysis**  
  The application processes the selected image using the integrated model.

- 📦 **Bounding Box Visualization**  
  Detected silkworm larvae are displayed with bounding boxes for easier result interpretation.

- 📊 **Detection Summary**  
  The application displays the total number of:
  - **Healthy (`H`)**
  - **Unhealthy (`UH`)**

- 💡 **Tips & Recommendations**  
  The application provides a health risk interpretation and corresponding recommendations based on the unhealthy detection ratio.

- 🕘 **Local Scan History**  
  Users can save scan results and review them later through the history section.

- 📘 **In-App Manual**  
  A manual page is available to guide users in using the application.

---

## 🧭 Main Application Sections

The Silkreto Mobile Application includes the following sections:

- **Home**
- **Scan**
- **Upload**
- **History**
- **Manual**

---

## 🚦 Health Risk Thresholds

The application computes the unhealthy ratio using:

Unhealthy Ratio = Unhealthy Count / (Healthy Count + Unhealthy Count)
Based on this ratio, the system displays the following health risk levels:

- **LOW HEALTH RISK**  
  **Threshold:** below **10%**  
  Unhealthy signs are minimal. Maintain hygiene, proper feeding, and stable conditions.

- **ELEVATED HEALTH RISK**  
  **Threshold:** **10% to 24%**  
  Unhealthy signs are already notable. Control actions such as isolation, sanitation, and environmental stabilization are recommended.

- **CRITICAL HEALTH RISK**  
  **Threshold:** **25% and above**  
  Unhealthy signs are severe and may indicate outbreak-level conditions. Immediate control and full sanitation are strongly recommended.

These risk levels are shown in the app through the **Tips & Recommendations** section after image analysis.

---

## ⚙️ Application Workflow

1. The user opens the application.
2. The user selects **Scan** or **Upload**.
3. The image is prepared and cropped if needed.
4. The application analyzes the image.
5. Detected larvae are shown with bounding boxes.
6. Healthy and unhealthy counts are shown.
7. The unhealthy ratio is computed.
8. A corresponding health risk level and recommendation set is shown.
9. The result can be saved to local history.

---

## ⚠️ Scope and Usage

The Silkreto Mobile Application is intended to support the observation of visible silkworm larvae conditions through mobile image analysis.

Please note that:

- results depend on image quality, lighting, angle, framing, and clarity
- the system may produce incorrect or missed detections in some cases
- the application is intended as a **decision-support tool**
- overlapping, blurred, or partially visible larvae may reduce detection accuracy
- the application does **not** replace expert diagnosis or laboratory confirmation

---

## 📬 Contact

If you have concerns, questions, or would like to request access to the project for **research or academic purposes**, you may contact the researcher via email.

📧 **Email:** jlegaspina8683@student.dmmmsu.edu.ph

Please include a brief description of your request and intended use when sending an email.