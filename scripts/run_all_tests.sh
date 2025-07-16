#!/bin/bash
# Run all Salesforce Apex tests and all LWC Jest tests

set -e

# Run all Jest (LWC) tests
npm run test:unit

# Run all Apex tests in the default org
sf apex test run --wait 1 --result-format human