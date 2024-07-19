#!/bin/bash

cp ./rime_mint.schema.yaml ./rime_mint_trime.schema.yaml
sed -i 's/^  # enable_correction: true/  enable_correction: true/' ./rime_mint_trime.schema.yaml
cp ./rime_mint.custom.yaml ./rime_mint_trime.custom.yaml
