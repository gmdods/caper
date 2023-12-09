using Documenter, Caper

makedocs(
	modules=[Caper, Caper.Reader],
	sitename="Caper",
	doctest=true
)
