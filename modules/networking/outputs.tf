output "vpc" {
  value = module.vpc #A
}

output "sg" {
  value = { #B
    lb     = module.lb_sg.security_group.id #B
    ecs    = module.ecs_sg.security_group.id #B
  } #B
}
