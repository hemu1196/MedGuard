# Review and pin this supported feature image to its tested digest before production deployment.
ARG CLAMAV_IMAGE=clamav/clamav:1.4
FROM ${CLAMAV_IMAGE}
COPY clamd.conf /etc/clamav/clamd.conf
EXPOSE 3310
