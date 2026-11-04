# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
#start registration
$source=$ua->get("$target/index.php?option=com_users&view=registration")->decoded_content;
if ($source =~ /registration.register/g or $source =~ /jform_password2/g or $source =~ /jform_email2/g) {
	dprint("Checking user registration");
	tprint("registration is enabled\n$target/index.php?option=com_users&view=registration");
}
#end registration
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
