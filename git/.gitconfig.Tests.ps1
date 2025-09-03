# .gitconfig 配置文件测试脚本
# 验证 Git 配置是否正确设置

# 测试核心配置
Describe "Core Configuration" {
    It "应该设置正确的编辑器" {
        $editor = git config --get core.editor
        $editor | Should Be "code --wait"
    }

    It "应该设置全局忽略文件" {
        $excludesFile = git config --get core.excludesfile
        $excludesFile | Should Be "~/.gitignore_global"
    }

    It "应该启用分页器" {
        $pager = git config --get core.pager
        $pager | Should Be "delta"
    }

    It "应该设置 autocrlf 为 false" {
        $autocrlf = git config --get core.autocrlf
        $autocrlf | Should Be "false"
    }

    It "应该设置默认分支为 main" {
        $defaultBranch = git config --get init.defaultBranch
        $defaultBranch | Should Be "main"
    }
}

# 测试别名配置
Describe "Alias Configuration" {
    It "应该设置 st 别名" {
        $stAlias = git config --get alias.st
        $stAlias | Should Be "status -sb"
    }

    It "应该设置 lg 别名" {
        $lgAlias = git config --get alias.lg
        $lgAlias | Should Be "log --oneline --decorate --graph"
    }

    It "应该设置 co 别名" {
        $coAlias = git config --get alias.co
        $coAlias | Should Be "checkout"
    }

    It "应该设置 ci 别名" {
        $ciAlias = git config --get alias.ci
        $ciAlias | Should Be "commit"
    }
}

# 测试颜色配置
Describe "Color Configuration" {
    It "应该启用自动颜色" {
        $colorUi = git config --get color.ui
        $colorUi | Should Be "auto"
    }

    It "应该设置分支颜色" {
        $colorBranch = git config --get color.branch.current
        $colorBranch | Should Be "yellow reverse"
    }

    It "应该设置差异颜色" {
        $colorDiff = git config --get color.diff.meta
        $colorDiff | Should Be "yellow bold"
    }
}

# 测试 Delta 配置
Describe "Delta Configuration" {
    It "应该启用导航" {
        $navigate = git config --get delta.navigate
        $navigate | Should Be "true"
    }

    It "应该启用行号" {
        $lineNumbers = git config --get delta.line-numbers
        $lineNumbers | Should Be "true"
    }

    It "应该设置语法主题" {
        $syntaxTheme = git config --get delta.syntax-theme
        $syntaxTheme | Should Be "Dracula"
    }
}