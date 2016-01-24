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

// Open ever selected link in a new tab. Pop-up blockers will probably need to be disabled...
function open_all(){
	var boxen = document.getElementsByName("link");
	var ids = {};

	for(var i = 0, len = boxen.length; i < len; i++){
		var box = boxen[i];

		ids[box.value] = box.checked;
	}

	// Get the table of links
	var tables = document.getElementsByClassName("links_table");

	for(var i = 0, len = tables.length; i < len; i++){
		var table = tables[i];

		// Get all a tags
		var links = table.getElementsByTagName("a");

		// Follow the link if id-link of a tag is in ids.
		for(var a = 0, len = links.length; a < len; a++){
			var link = links[a];

			if(ids[link.getAttribute("id-link")])
				window.open(link.href);
		}
	}
}

function select_all(){
	var boxen = document.getElementsByName("link");

	for(var i = 0, len = boxen.length; i < len; i++)
		boxen[i].checked = true;
}
