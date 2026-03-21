# ==============================================================================
# TURAS Analytics Platform - Docker Image
# ==============================================================================
# Builds a self-contained Shiny Server image with all R dependencies pre-installed
# via renv. Data is mounted at /data at runtime.
#
# BUILD:   docker build -t turas .
# RUN:     docker-compose up
# ==============================================================================

FROM rocker/shiny:4.5.1

LABEL maintainer="Duncan Brett <duncan@researchlamppost.co.za>"
LABEL description="TURAS Analytics Platform - Market Research Toolkit"

# System libraries required by R packages
# - libxml2-dev: xml2, rvest
# - libcurl4-openssl-dev: httr, curl
# - libssl-dev: openssl
# - libfontconfig1-dev: systemfonts (used by ggplot2/ragg)
# - libfreetype6-dev: systemfonts, ragg
# - libpng-dev: png (used by ragg)
# - libtiff-dev: tiff (used by ragg)
# - libjpeg-dev: jpeg
# - libharfbuzz-dev, libfribidi-dev: textshaping (ggplot2 dependency)
# - libgit2-dev: gert (used by renv)
# - zlib1g-dev: general compression
# - cmake: some compiled packages
# - libglpk-dev: igraph (dependency of some stats packages)
# - libgmp3-dev: gmp
# - libmpfr-dev: Rmpfr
RUN apt-get update && apt-get install -y --no-install-recommends \
    libxml2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff-dev \
    libjpeg-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libgit2-dev \
    zlib1g-dev \
    cmake \
    libglpk-dev \
    libgmp3-dev \
    libmpfr-dev \
    && rm -rf /var/lib/apt/lists/*

# Set the application directory
ENV TURAS_ROOT=/srv/shiny-server/turas
ENV TURAS_DOCKER=1
WORKDIR ${TURAS_ROOT}

# Copy renv infrastructure first (for Docker layer caching)
COPY renv.lock renv.lock
COPY .Rprofile .Rprofile
COPY renv/activate.R renv/activate.R

# Install renv and restore packages from lock file
# This is the slow step — cached unless renv.lock changes
RUN R -e "install.packages('renv', repos = 'https://cloud.r-project.org')" && \
    R -e "renv::consent(provided = TRUE); renv::restore()"

# Copy the full application
COPY . .

# Create data mount point
RUN mkdir -p /data

# Configure Shiny Server to serve Turas
RUN echo '\
run_as shiny;\n\
\n\
server {\n\
  listen 3838;\n\
\n\
  location / {\n\
    site_dir /srv/shiny-server/turas;\n\
    log_dir /var/log/shiny-server;\n\
    directory_index on;\n\
    app_init_timeout 120;\n\
    app_idle_timeout 1800;\n\
  }\n\
}\n' > /etc/shiny-server/shiny-server.conf

# Create a simple app.R wrapper that launches Turas
RUN echo '\
# Turas Shiny App Entry Point (Docker)\n\
Sys.setenv(TURAS_ROOT = "/srv/shiny-server/turas")\n\
Sys.setenv(TURAS_DOCKER = "1")\n\
setwd(Sys.getenv("TURAS_ROOT"))\n\
source("launch_turas.R")\n\
launch_turas()\n' > /srv/shiny-server/turas/app.R

# Expose Shiny Server port
EXPOSE 3838

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3838/ || exit 1

# Run Shiny Server
CMD ["/usr/bin/shiny-server"]
