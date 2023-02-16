
module "networking" {
  source    = "./modules/networking" #A
  namespace = var.namespace #B
}

module "ecs" {
  source    = "./modules/ecs"
  namespace = var.namespace
  vpc       = module.networking.vpc
  sg        = module.networking.sg
}

