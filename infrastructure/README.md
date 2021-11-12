# Infrastructure

## Tree of folder structure and file purpose
├── common
│   ├── NuGet.config - Standard config file for codebuild to access nuget repos
│   ├── cloudformations
│   │   └── infrastructure-cft-{app-name}.yaml - Application supporting EC2 infrastructure CloudFormation Template
│   └── pipelines
│       |── {app-name}-cft-pipeline.yaml - Code Pipeline CloudFormation Template
│       ├── appspec.yml - Standard appspec file for Windows OS configurations on EC2 Stage
|       ├── before-appspec.ps1 - Prepwork on ec2, mostly to account for in use files.
│       ├── buildspec.yml - Standard file for Codebuild stage
│       └── install-appspec.ps1 - Standard file for Windows OS configurations on EC2 Stage
└── dev
    └── infrastructure-cft-{app-name}-param.json - Application supporting EC2 param file for the infrastructure CloudFormation Template