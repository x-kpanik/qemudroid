#!/bin/bash

export $(allurectl job-run env | grep ALLURE | xargs -L1)

allurectl upload --project-id $ALLURE_PROJECT_ID build/reports/marathon/device-files/allure-results

exit 0
