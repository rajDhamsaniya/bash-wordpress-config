# Shell script to install and configure the wordpress site.

## Assumption
- It is assumed that after creating the site user privilages will be set by manually through going to link.
- It is also assumed that it is not necessary to generate SSL certificate and configure it so it is skipped.

## Instruction
- clone the repo
- This is help menu for the code
```
         -d, --domain
                 For providing domain name.

         -h , --help
                 Help Menu

         -p, --dbpass
                 Password for provided username if MySql already installed

         -r, --remove
                 remove installed wordpress website only. It accepts domain name of website to remove. It must be inserted at the end of command.

         -u, --dbuser
                 UserName for MySql Database if already installed
```
- For fresh installation run provided code
```
sudo su
./Challange_A.sh -d example.com
```
