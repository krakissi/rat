// stack.js
// mperron (2014)
//
// Javascript bits specific to stack.html.

// Procs a confirmation dialog before submitting the form to trigger a stack_remove
function delete_stack(){
	if(confirm("Permanently delete this stack?\nThis operation cannot be undone."))
		document.forms["form_stack_remove"].submit();
}

function delete_links(){
	if(confirm("Permanently remove selected links?"))
		document.forms["form_link_remove"].submit();
}
