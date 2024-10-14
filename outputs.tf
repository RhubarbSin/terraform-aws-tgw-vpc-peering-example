output "primary_instance_private_ip" {
  value = module.primary_instance["primary"].private_ip
}

output "primary_instance_public_ip" {
  value = module.primary_instance["primary"].public_ip
}

output "primary_peer_instance_private_ip" {
  value = module.primary_instance["primary_peer"].private_ip
}

output "primary_peer_instance_public_ip" {
  value = module.primary_instance["primary_peer"].public_ip
}

output "secondary_instance_private_ip" {
  value = module.secondary_instance.private_ip
}

output "secondary_instance_public_ip" {
  value = module.secondary_instance.public_ip
}

output "ssh_private_key_file_name" {
  value = basename(local_sensitive_file.this.filename)
}
