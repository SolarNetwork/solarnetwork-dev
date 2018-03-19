{
	# look for <section name="SourceActionDialog.methods" to insert into
	if ( $0~("<section name=\"SourceActionDialog.methods\"") ) {
		# found section; assume we will insert new <list> unless we find one already
		p=1;
		n=1;
	}
	if ( p == 1 ) {
		if ( $0~("<list key=\"ToStringTemplateNames\"") ) {
			n=0;
		}
	}
	if ( $0~("</section>") ) {
		if ( p == 1 && n == 1 ) {
			printf("%s","<list key=\"ToStringTemplates\"><item value=\"${object.className}{${member.name()}=${member.value},${otherMembers}}\"/></list><list key=\"ToStringTemplateNames\"><item value=\"SolarNetwork\"/></list>\n");
		}
		p=0;
	}
	printf("%s\n",$0)
}
