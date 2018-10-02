# installation

copy raspbian to sd-card

## Pre-installation configuration

### Create a new OpenPGP key-pair

//TODO: Tutorial on setting up a new OpenGP-key with GPG.

### Setup the SD-card

  * Add an empty file named "ssh" to the boot partition
  * Add the created OpenPGP-key to the boot partition with the following filename: "riotbox.openpgp"
  * Add a file named "email" to the boot partition
    * Open the file "email" with your text editor and enter your email-address in it.
    * save & close the file.
  * Copy the file "files/ssmtp.conf" to the boot partition.
    * Open "ssmtp.conf" and change it to the configuration of your email provider.

    # The user that gets all the mails (UID < 1000, usually the admin)
    pi=username@gmail.com

    # The mail server (where the mail is sent to), both port 465 or 587 should be acceptable
    # See also https://support.google.com/mail/answer/78799
    mailhub=smtp.gmail.com:587

    # The address where the mail appears to come from for user authentication.
    rewriteDomain=gmail.com

    # The full hostname.  Must be correctly formed, fully qualified domain name or GMail will reject connection.
    hostname=localhost.localhost.org

    # Use SSL/TLS before starting negotiation
    UseTLS=Yes
    UseSTARTTLS=Yes

    # Username/Password
    AuthUser=username
    AuthPass=password
    AuthMethod=LOGIN

    # Email 'From header's can override the default domain?
    FromLineOverride=yes

## installation

  * Insert the SD-card into your raspberry pi
  * Connect the ethernet cable to the pi and your router
  * Connect the power cable to the pi
  * The LEDs of the raspberry pi should blink now.
  * You will receive an encrypted email when the installation is finished.
