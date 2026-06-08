Build a production-ready Flutter Web PWA and Node.js backend that acts as an HTTP directory browser and file download manager.

Frontend:

* Flutter Web
* Material 3
* Responsive design for desktop, Android, and iPhone Safari
* AMOLED dark theme
* Installable PWA
* Provider or Riverpod state management

Features:

* Browse Apache/Nginx-style HTTP directory listings
* Breadcrumb navigation
* Back and Up navigation
* Search files and folders
* Sort by name, size, and modified date
* Download manager page
* Download queue
* Real-time progress bars
* Download speed and ETA
* Pause, resume, retry, and cancel downloads
* Download history
* Settings page

Backend:

* Node.js + Express
* SQLite database
* Cheerio-based directory parsing
* Axios networking
* SOCKS5 support using socks-proxy-agent
* REST API endpoints for browsing, searching, and downloading

Download Engine:

* Concurrent downloads
* Configurable concurrency limits
* Resume support using HTTP Range requests
* Progress tracking
* Speed calculation
* ETA calculation
* Persistent download state

PWA:

* Offline shell
* Manifest
* Service worker
* Home-screen installation support

Code requirements:

* Clean architecture
* Strong typing
* Error handling
* Logging
* Unit tests where appropriate
* Production-ready folder structure
* Complete setup and deployment instructions

Generate the project incrementally, starting with backend APIs and Flutter project structure before implementing advanced features.
