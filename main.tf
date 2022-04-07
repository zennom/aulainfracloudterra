terraform {
  required_version = ">= 0.13"
  required_providers{
    azurerm = {
        source = "hashicorp/azurerm"
        version = ">= 2.26"
    }
  }
}

provider "azurerm" {
    features {}
}

resource "azurerm_resource_group" "rg-aulainfra" {
  name     = "aulainfracloudterra"
  location = "centralus"
}
resource "azurerm_virtual_network" "vnet-aulainfra" {
  name                = "vnet"
  location            = azurerm_resource_group.rg-aulainfra.location
  resource_group_name = azurerm_resource_group.rg-aulainfra.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "Production"
    turma = "FS04"
    faculdade = "Impacta"
    aluno = "Viviane de Lima"
    Professor = "João Henrique"
  }
}


resource "azurerm_subnet" "sub-aulainfra" {
  name                 = "subnet"
  resource_group_name  = azurerm_resource_group.rg-aulainfra.name
  virtual_network_name = azurerm_virtual_network.vnet-aulainfra.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "ip-aulainfra" {
  name                    = "publicip"
  location                = azurerm_resource_group.rg-aulainfra.location
  resource_group_name     = azurerm_resource_group.rg-aulainfra.name
  allocation_method       = "Static"

  tags = {
    environment = "test"
  }
}

resource "azurerm_network_security_group" "nsg-aulainfra" {
  name                = "nsg"
  location            = azurerm_resource_group.rg-aulainfra.location
  resource_group_name = azurerm_resource_group.rg-aulainfra.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "80"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

    security_rule {
    name                       = "Web"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_interface" "nic-aulainfra" {
  name                = "nic"
  location            = azurerm_resource_group.rg-aulainfra.location
  resource_group_name = azurerm_resource_group.rg-aulainfra.name

  ip_configuration {
    name                          = "nic-ip"
    subnet_id                     = azurerm_subnet.sub-aulainfra.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.ip-aulainfra.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic-nsg-aulainfra" {
  network_interface_id      = azurerm_network_interface.nic-aulainfra.id
  network_security_group_id = azurerm_network_security_group.nsg-aulainfra.id
}

resource "azurerm_storage_account" "sa-aulainfra" {
  name                     = "saaulainfra"
  resource_group_name      = azurerm_resource_group.rg-aulainfra.name
  location                 = azurerm_resource_group.rg-aulainfra.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "staging"
  }
}

resource "azurerm_linux_virtual_machine" "vm-aulainfra" {
  name                = "vm"
  resource_group_name = azurerm_resource_group.rg-aulainfra.name
  location            = azurerm_resource_group.rg-aulainfra.location
  size                = "Standard_D2ads_v5"
  network_interface_ids = [
    azurerm_network_interface.nic-aulainfra.id,
  ]

   admin_username      = "adminuser"
   admin_password      = "Password1234!" 
   disable_password_authentication = false
   
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
    name = "mydisk"
    caching = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.sa-aulainfra.primary_blob_endpoint
  }

}

data "azurerm_public_ip" "ip-aulainfra-data"{
    name = azurerm_public_ip.ip-aulainfra.name
    resource_group_name = azurerm_resource_group.rg-aulainfra.name
}

resource "null_resource" "install-webserver" {

  connection {
    type = "ssh"
    host = data.azurerm_public_ip.ip-aulainfra-data.ip_address
    user = "adminuser"
    password = "Password1234!"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y apache2"
    ]
  }

    depends_on = [
      azurerm_linux_virtual_machine.vm-aulainfra
    ]
}