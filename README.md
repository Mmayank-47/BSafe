# bSafe

Welcome to bSafe, a comprehensive women's safety app designed to provide you with peace of mind and support in times of need. Whether you're commuting, traveling, or simply going about your daily activities, bSafe is here to ensure your safety with a suite of powerful features.

## Demo Preview   
[![bSafe Demo](https://img.youtube.com/vi/gUbb2mIZKwU/1.jpg)](https://youtu.be/gUbb2mIZKwU)  

## Hosted URL
Download the latest APK and start playing! 🎮  

<a href="https://bit.ly/3E1WP8a" target="_blank">
  <img src="https://github.com/user-attachments/assets/4e7ed9b6-7f35-4f5e-bde1-0aff6df104c4" alt="Download APK" width="100" height ="100"/>
</a>  

🔽 **Click Below to Download** 🔽  
[📥 Download APK](https://bit.ly/3E1WP8a)  



## Table of Contents
- [Screenshots](#screenshots)
- [Features](#features)
- [Technologies Used](#technologies-used)
- [Usage](#usage)
- [Installation](#installation)

## Screenshots
![WhatsApp Image 2024-06-09 at 11 28 24_e43ad016](https://github.com/ajax-39/CodeClauseInternship_bSafe/assets/129135590/df66c66c-b11d-4e8c-8236-d86ab80ad258)
![WhatsApp Image 2024-06-09 at 11 28 24_dbedad1b](https://github.com/ajax-39/CodeClauseInternship_bSafe/assets/129135590/d98e74fe-dd67-4dc6-ad9c-23dd7e43150e)
![WhatsApp Image 2024-06-09 at 12 26 01_764c7f5e](https://github.com/ajax-39/CodeClauseInternship_bSafe/assets/129135590/21954a1b-02c8-4ce0-a331-2613330ce3a7)
![WhatsApp Image 2024-06-09 at 11 28 24_368bf141](https://github.com/ajax-39/CodeClauseInternship_bSafe/assets/129135590/78f620b3-bb48-4b68-a4e2-96d5ffc9e3af)
![WhatsApp Image 2024-07-11 at 22 41 44_bf26502b](https://github.com/ajax-39/CodeClauseInternship_bSafe/assets/129135590/d6dd642c-cad3-4b26-9dd8-23a3fdf9a078)
![WhatsApp Image 2024-06-09 at 11 28 23_d1f895ba](https://github.com/ajax-39/CodeClauseInternship_bSafe/assets/129135590/bff30f8e-26e6-4a38-bff0-285e56939479)

## Features

### SOS Alert
- **Instant SOS**: Send an emergency alert with your current location and a custom message to your trusted contacts with a single tap.
- **Location Sharing**: Include your current location (latitude and longitude) in the SOS message to help your contacts quickly identify your whereabouts.
- **Custom Message**: Personalize the SOS message according to your needs.
- **Multiple Contacts**: Add multiple trusted contacts to receive the SOS alert, increasing the chances of getting help promptly.

### Location Services
- **Real-Time Location Tracking**: Track and display your real-time location on the map using Google Maps.
- **Interactive Maps**: View your current position and navigate to various safe places or emergency contacts.
- **Markers and Directions**: Set markers for important locations and get directions to these places.

### Emergency Services Locations
- **Nearby Services**: Display nearby emergency services like police stations, hospitals, and shelters.
- **One-Tap Calling**: Call nearby police stations, hospitals, and other essential services with one tap.
- **One-Tap Directions**: Get directions to nearby emergency services instantly.

### Motivation and Self-Defense
- **Motivational Page**: Get inspired by a dedicated page full of motivational quotes and stories tailored for women.
- **Self-Defense Articles**: Read articles about self-defense techniques and strategies to empower yourself and stay prepared.

## Technologies Used
- **Flutter**: For building the app's UI.
- **Firebase**: For backend services such as authentication, real-time database, and cloud messaging.
- **Google Maps API**: For real-time location tracking and interactive maps.

## Usage

1. Open the app and register or log in.
2. Add trusted contacts to receive SOS alerts.
3. Use the SOS button in an emergency to send alerts to your contacts.
4. Track your location and navigate to safe places using the map features.
5. Access emergency services with one-tap calling and directions.
6. Read motivational quotes and self-defense articles to stay inspired and prepared.

## Installation

To get a local copy up and running, follow these simple steps:

### Prerequisites
- **Flutter**: Ensure you have Flutter installed on your machine.
- **Firebase CLI**: For deploying Firebase resources.

### Setup

1. Clone the repository:
    ```bash
    git clone https://github.com/your-username/bSafe.git
    cd bSafe
    ```

2. Install dependencies:
    ```bash
    flutter pub get
    ```

3. Setup Firebase:
    - Create a Firebase project in the [Firebase Console](https://console.firebase.google.com/).
    - Add your Android and iOS apps to the Firebase project.
    - Download the `google-services.json` file for Android and `GoogleService-Info.plist` for iOS, and place them in the respective directories:
        ```bash
        android/app
        ios/Runner
        ```
    - Initialize Firebase in your project:
        ```bash
        firebase init
        ```
    Follow the prompts to set up Firestore, Authentication, and Cloud Messaging.

