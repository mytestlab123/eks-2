# VPC Usage Policy — DEV Profile

## Default VPC for Labs

**Always use:** `vpc-035eb12babd9ca798` (stata-vpc)
- This is the default VPC for development and lab work
- Use without asking for approval

## Restricted VPC

**Requires approval:** `vpc-06814ea8b57b55627` (Synapxe TRUST Dev)
- Private subnets only (no public subnets)
- Limited IP availability
- Must get explicit user approval before using
- Used for specific TRUST project work only

## Workflow

1. Default: Use `stata-vpc` for all EKS labs
2. If TRUST VPC is needed:
   - Ask user for approval first
   - Document reason for using it
   - Verify subnet IP availability before proceeding
