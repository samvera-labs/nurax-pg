ARG HYRAX_IMAGE_VERSION=3.0.2
FROM ghcr.io/samvera/hyrax/hyrax-base:$HYRAX_IMAGE_VERSION as build-base

USER root
RUN apk --no-cache add \
  bash \
  ffmpeg \
  git \
  less \
  mediainfo \
  openjdk11-jre \
  perl \
  postgresql-client
USER app

RUN mkdir -p /app/fits && \
    cd /app/fits && \
    wget https://github.com/harvard-lts/fits/releases/download/1.5.0/fits-1.5.0.zip -O fits.zip && \
    unzip fits.zip && \
    rm fits.zip && \
    chmod a+x /app/fits/fits.sh
ENV PATH="${PATH}:/app/fits"

FROM ghcr.io/samvera/hyrax/hyrax-base:$HYRAX_IMAGE_VERSION as ruby-base
ARG DOCKERROOT=/app/samvera

USER app

COPY --chown=1001:101 Gemfile* $DOCKERROOT/hyrax-webapp/

RUN bundle check || bundle install --jobs "$(nproc)"

COPY --chown=1001:101 scripts/db-migrate-seed.sh $DOCKERROOT/db-migrate-seed.sh
COPY --chown=1001:101 . $DOCKERROOT/hyrax-webapp
COPY --chown=1001:101 scripts ${DOCKERROOT}/scripts/

RUN RAILS_ENV=production SECRET_KEY_BASE=`bin/rake secret` DB_ADAPTER=nulldb DATABASE_URL='postgresql://fake' bundle exec rake assets:precompile

#
# Rails server
FROM build-base as nurax-pg
ARG DOCKERROOT=/app/samvera

COPY --from=ruby-base --chown=1001:101 /usr/local/bundle/ /usr/local/bundle/
COPY --from=ruby-base --chown=1001:101 ${DOCKERROOT} ${DOCKERROOT}

ENTRYPOINT ["/app/samvera/hyrax-webapp/scripts/entrypoint.sh"]
CMD ["bundle", "exec", "puma"]

#
# Sidekiq worker
FROM build-base as nurax-pg-worker
ARG DOCKERROOT=/app/samvera

ENV MALLOC_ARENA_MAX=2

COPY --from=ruby-base --chown=1001:101 /usr/local/bundle/ /usr/local/bundle/
COPY --from=ruby-base --chown=1001:101 ${DOCKERROOT} ${DOCKERROOT}

ENTRYPOINT ["/app/samvera/hyrax-webapp/scripts/entrypoint.sh"]
CMD ["bundle", "exec", "sidekiq"]
