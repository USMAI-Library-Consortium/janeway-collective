# Janeway Collective

A Helm Chart designed to easily deploy Janeway. This deployment uses Nginx and
Gunicorn, and contains all default Janeway cron jobs re-implemented as
Kubernetes cronjobs. This helm chart can be use to deploy multiple Janeway
instances (a _collective_) by using multiple releases.

## Test Rendering the Template

It can be helpful to test render this template. This will show any render
errors as well as allow you to inspect the output.

1. Create a values file with the remaining required values that don't
   have defaults. If you create a `./tmp` folder in root, you can store
   these files there without them being tracked in source control.
2. Run `helm template janeway ./ -f tmp/yourValuesFileName.yaml`

## Packaging this Helm Chart

To package this Helm chart for distribution, increment the 'version' in
Chart.yaml and run the following command:

`helm package . -d ./dist`

You may need to create the `dist` folder if it's not there. You may then
upload the resulting tar file to your Helm repository.
