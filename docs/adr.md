# Architecture Decision Record

This document attempts to describe the architecture of this repository
through its major design decisions.

## ADR-1: Component Labels

The `app.kubernetes.io/component` label is important to being able to
query resources defined in the stack properly. This ADR defines
the correct way to set them.

### Decision

The best practice for the component label is to describe what part of
the stack that resource applies to. This would usually describe a
real component of the system (server, frontend, database, etc.). This
should include all resources that apply to that system (netpol,
services, ingresses, etc).

## ADR-2: Label & Annotation Templating Strategy

As you may notice, the labels and annotations use a templating strategy
that seems complex:

```helm
{{- $labels := include "common.tplvalues.merge" ( dict "values" ( list .Values.labels .Values.commonLabels ) "context" . ) }}
  labels: {{- include "common.labels.standard" ( dict "customLabels" $labels "context" $ ) | nindent 4 }}
    {{ include "common.labels.component.app" . }}
```

This templating strategy uses the Bitnami 'common' helm chart, which is
a dependency that provides utilities to make helm templating easier.
I originally did my label / annotation templating in this way so that
the Janeway chart could integrate neatly with other bitnami charts, as
they would both share the same templating resources.

I am no longer using the Bitnami Postgres chart, but this is still a neat way
of doing labels. It also allows downstream users to override stock labels
/ annotations by providing their own 'common' chart or to add their
own labels / annotations as though the `labels`, `annotations`, `commonLabels`,
etc varibles. The more specific variables (`labels`, `annotations`) override
the more general variables (`commonLabels`, `commonAnnotations`).

Let's take at an example so that I can explain what's going on:

```helm
{{- $labels := include "common.tplvalues.merge" ( dict "values" ( list .Values.labels .Values.commonLabels ) "context" . ) }}
  labels: {{- include "common.labels.standard" ( dict "customLabels" $labels "context" $ ) | nindent 4 }}
    {{ include "common.labels.component.app" . }}
```

* First Line: Create a string-yaml 'labels' variable from the merged labels and
  commonLabels variables. This allows users to define labels that they want
  their resources to have, and there are various different ones (
  `service.labels`, `podLabels`, etc) The values of these variables allow for
  templating, which is NOT a default of helm veriable values. This is nice as
  we could implement UMD's part-of labels through that feature:

    ```helm
    commonLabels:
        app.kubernetes.io/part-of: "{{ .Chart.Name }}" 
    ```

* Second Line: Render the Bitnami common labels list, which sets up many best-practice
  labels, in addition to the additional labels we merged in the first line.
* Third Line: Add the app.kubernetes.io/component label discussed in ADR-1.
