# ==============================================================================
# TURAS Analytics Platform - Docker Image
# ==============================================================================
# Builds a self-contained image with all R dependencies pre-installed via renv.
# Runs R directly (no Shiny Server). Data is mounted at /data at runtime.
#
# BUILD:   docker build -t turas .
# RUN:     docker-compose up
# ==============================================================================

FROM rocker/shiny:4.5.3

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
    curl \
    && rm -rf /var/lib/apt/lists/*

# Node.js — required by the minification pipeline (terser, clean-css, html-minifier-terser, javascript-obfuscator)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    npm install -g terser clean-css-cli html-minifier-terser javascript-obfuscator && \
    rm -rf /var/lib/apt/lists/*

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
# Two-pass restore: first pass installs most packages, second pass catches
# any that failed due to dependency ordering issues in parallel builds
# Disable renv's symlink cache — packages must be COPIED into the project
# library, not symlinked to /root/.cache (which the shiny user cannot read).
ENV RENV_CONFIG_CACHE_SYMLINKS=FALSE

RUN R -e "install.packages('renv', repos = 'https://cloud.r-project.org')" && \
    R -e "renv::consent(provided = TRUE); tryCatch(renv::restore(), error = function(e) message('First pass done, retrying failures...'))" && \
    R -e "renv::consent(provided = TRUE); renv::restore()"

# Copy the full application
COPY . .

# Overwrite Renviron.site to:
# 1. Include renv library FIRST in R_LIBS (before system libraries)
# 2. Skip renv bootstrap at runtime
RUN printf 'R_LIBS=/srv/shiny-server/turas/renv/library/linux-ubuntu-noble/R-4.5/x86_64-pc-linux-gnu:/usr/local/lib/R/site-library:/usr/local/lib/R/library\nTURAS_SKIP_RENV=1\n' > /usr/local/lib/R/etc/Renviron.site

# Create data mount point
RUN mkdir -p /data

# Expose ports: 3838 = launcher, 3839-3848 = module sessions
EXPOSE 3838 3839-3848

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3838/ || exit 1

# Run R directly — launch_turas() calls runApp() internally.
# Shiny options set host to 0.0.0.0 (container-accessible) and port 3838.
CMD ["R", "-e", "options(shiny.host='0.0.0.0', shiny.port=3838L); source('launch_turas.R')"]
