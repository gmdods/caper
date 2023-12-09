using Documenter, Caper

makedocs(
	modules=[Caper],
	sitename="Caper",
	doctest=true,
	format=Documenter.HTML(;edit_link="master"),
	repo=Remotes.GitHub("gmdods", "caper")
)
