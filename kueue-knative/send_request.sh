#!/bin/bash

set -x

URL=http://llama3.default.kueue-dev.gcp.jkwong.info
#URL=http://llama3-spot.default.kueue-dev.gcp.jkwong.info

curl -i -X POST \
    ${URL}/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "meta-llama/Meta-Llama-3.1-8B-Instruct",
        "prompt": "You are a helpful bot.  Be brief in the answer in one or two sentences only. Do not provide additional definitions.\n\nDefine what Kubernetes is. ",
        "max_tokens": 30,
        "temperature": 0
    }'