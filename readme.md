# Janeway Collective

A Helm Chart designed to easily deploy Janeway. This deployment uses Nginx and
Gunicorn, and contains all default Janeway cron jobs re-implemented as
Kubernetes cronjobs. This helm chart can be use to deploy multiple Janeway
instances (a _collective_) by using multiple releases.

IMPORTANT NOTE: This repository contains an optional **Bitnami Postgres**
subchart, the docker image of which is paywalled as of August 2025. You can
still use this subchart if you build the docker image yourself and
override the repository.
