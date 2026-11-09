# mipOS edit to 8.30 Shadow: no "passwd root" (it asks for a password).
# The live system and the installer set up accounts themselves.
/^passwd root$/d
