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
