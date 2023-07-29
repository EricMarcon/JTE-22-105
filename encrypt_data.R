# Data enryption ####
# Encrypt private data in a public repository
# data are stored in a vault that requires the project's private key to be read
# GitHub Actions read the key in a project secret
# Required: the project's key pair
# .gitignore: *.rsa and data/


## Installation of packages if necessary ####
InstallPackages <- function(Packages) {
  InstallPackage <- function(Package) {
    if (!Package %in% installed.packages()[, 1]) {
      install.packages(Package, repos="https://cran.rstudio.com/")
    }
  }
  invisible(sapply(Packages, InstallPackage))
}
InstallPackages(c("secret", "tidyverse"))

# Data encryption ####
name_project <- "GF-Richness"
name_github_user <- "EricMarcon"
# If the GitHub user has several keys, which one to use? 1 by default.
index_github_user <- 3

## Create the vault ####
library("secret")
library("openssl")
# Create a vault
vault <- "vault"
create_vault(vault)
# Generic user of the project (public key in the project)
rsa_project <- read_pubkey(paste0(name_project, ".rsa.pub"))
# Add a user named after the project
add_user(name_project, public_key = rsa_project, vault = vault)
# Project's owner (public key on GitHub)
add_github_user(name_github_user, vault = vault, i = index_github_user)

## Prepare the data  ####
library("tidyverse")
# GuyaDiv 1-ha plots
read_csv2("data/ParcellesGUYADIV_2021.csv") %>%
  filter(Surf==1) %>%
  select(Parcelle, Localité, X_UTM, Y_UTM) %>%
  rename(Plot=Parcelle, Location=Localité) ->
  Plots
# GuyaDiv tree species abundances
read_csv2("data/GUYADIV_202107.csv") %>%
  select(Parcelle, Taxon) %>%
  rename(Plot=Parcelle) %>%
  inner_join(Plots) %>%
  select(Plot,Taxon) %>%
  group_by(Plot, Taxon) %>%
  summarize(Abundance=n(), .groups='drop') %>%
  pivot_wider(names_from=Taxon, values_from=Abundance, values_fill=0) ->
  Abundances
# Paracou abundance data
read_csv2("data/Paracou.csv", col_names=FALSE) %>%
  pull(X1) ->
  Paracou_abd

## Store secrets ####
add_secret("Plots", value = Plots, users = c(paste0("github-", name_github_user), name_project), vault = vault)
add_secret("Abundances", value = Abundances, users = c(paste0("github-", name_github_user), name_project), vault = vault)
add_secret("Paracou_abd", value = Paracou_abd, users = c(paste0("github-", name_github_user), name_project), vault = vault)


# Test ####
list_secrets(vault = vault)
list_owners("Plots", vault = vault)
list_owners("Abundances", vault = vault)
list_owners("Paracou_abd", vault = vault)
# Decrypt with the private key of the project
Sys.setenv(USER_KEY = usethis::proj_path(paste0(name_project, ".rsa")))
local_key()
get_secret("Plots", vault = vault)
get_secret("Abundances", vault = vault)
get_secret("Paracou_abd", vault = vault)
