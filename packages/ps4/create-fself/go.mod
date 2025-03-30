module github.com/OpenOrbis/create-fself

go 1.17

replace (
        github.com/OpenOrbis/create-fself/pkg/fself => ./pkg/fself
        github.com/OpenOrbis/create-fself/pkg/oelf => ./pkg/oelf
)