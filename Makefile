# Build the project
build :; forge build && FOUNDRY_PROFILE=0_6_x forge build

# Run tests
tests :; forge test