@echo off
setlocal enabledelayedexpansion

echo ===============================================
echo    Git 历史清理工具 - Windows Dotfiles
echo ===============================================
echo.

:: 检查是否在正确目录
if not exist ".git" (
    echo 错误：当前目录不是 Git 仓库
    pause
    exit /b 1
)

:: 显示当前状态
echo 📊 当前仓库状态：
git log --oneline -5
echo.
for /f %%i in ('git rev-list --count HEAD') do set commit_count=%%i
echo 总提交数：!commit_count!
echo.

:: 确认操作
echo ⚠️  警告：此操作将完全清理Git历史记录！
echo.
echo 将会执行以下操作：
echo 1. 创建备份分支 (backup-before-reset)
echo 2. 创建全新的Git历史
echo 3. 保留当前所有文件内容
echo 4. 创建一个干净的初始提交
echo.
set /p confirm="确定要继续吗？(输入 YES 继续): "
if not "!confirm!"=="YES" (
    echo 操作已取消。
    pause
    exit /b 0
)

echo.
echo 🚀 开始清理历史...
echo.

:: 1. 创建备份分支
echo 1/6 创建备份分支...
git branch backup-before-reset
if errorlevel 1 (
    echo 创建备份分支失败！
    pause
    exit /b 1
)
echo ✅ 备份分支创建成功

:: 2. 创建孤立分支
echo 2/6 创建孤立分支...
git checkout --orphan temp-clean
if errorlevel 1 (
    echo 创建孤立分支失败！
    pause
    exit /b 1
)
echo ✅ 孤立分支创建成功

:: 3. 添加所有文件
echo 3/6 添加所有文件...
git add .
if errorlevel 1 (
    echo 添加文件失败！
    pause
    exit /b 1
)
echo ✅ 文件添加成功

:: 4. 创建初始提交
echo 4/6 创建初始提交...
git commit -m "🎉 Initial commit - Windows Dotfiles

✨ Features:
- 现代化的 Windows dotfiles 管理系统
- 支持 PowerShell, Git, Windows Terminal, Starship 配置
- 智能安装脚本和健康检查工具
- 一键部署和模块化管理

🛡️ Security:
- 完善的隐私保护机制
- 安全的个人配置管理
- 模板化配置系统

📚 Documentation:
- 详细的使用指南和快速开始文档
- 完整的故障排除指南
- 清晰的项目结构说明"

if errorlevel 1 (
    echo 创建提交失败！
    echo 正在恢复到原分支...
    git checkout main
    git branch -D temp-clean
    pause
    exit /b 1
)
echo ✅ 初始提交创建成功

:: 5. 替换主分支
echo 5/6 替换主分支...
git branch -D main
if errorlevel 1 (
    echo 删除原主分支失败！
    pause
    exit /b 1
)
git branch -m main
if errorlevel 1 (
    echo 重命名分支失败！
    pause
    exit /b 1
)
echo ✅ 主分支替换成功

:: 6. 显示结果
echo 6/6 清理完成！
echo.
echo 📊 新的仓库状态：
git log --oneline
echo.
for /f %%i in ('git rev-list --count HEAD') do set new_count=%%i
echo 新的提交数：!new_count!
echo.

:: 推送选项
echo 📤 推送选项：
echo 1. 现在推送到远程 (会覆盖远程历史)
echo 2. 稍后手动推送
echo.
set /p push_choice="请选择 (1 或 2): "

if "!push_choice!"=="1" (
    echo.
    echo ⚠️  最后确认：这将覆盖远程仓库的所有历史！
    set /p final_confirm="输入 PUSH 确认推送: "
    if "!final_confirm!"=="PUSH" (
        echo 正在推送到远程...
        git push origin main --force
        if errorlevel 1 (
            echo 推送失败！请检查网络连接和权限。
            echo 你可以稍后手动执行：git push origin main --force
        ) else (
            echo ✅ 推送成功！
        )
    ) else (
        echo 推送已取消。
        echo 如需推送，请手动执行：git push origin main --force
    )
) else (
    echo 📝 后续操作：
    echo 如需推送到远程，请执行：git push origin main --force
)

echo.
echo 🎉 历史清理完成！
echo.
echo 📋 重要信息：
echo - 备份分支：backup-before-reset
echo - 如需恢复：git checkout backup-before-reset
echo - 清理备份：git branch -D backup-before-reset
echo.
echo 🔗 设置仓库为公开：
echo 1. 访问 GitHub 仓库页面
echo 2. 进入 Settings ^> General
echo 3. 滚动到 Danger Zone
echo 4. 点击 Change repository visibility
echo 5. 选择 Make public
echo.

pause
