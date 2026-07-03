import SwiftUI
import SwiftData

// MARK: - 首次启动引导
//
// 4 步引导：
// 1. 欢迎 + 介绍
// 2. 选择主题（4 套主题实时预览）
// 3. 配置微信读书 API Key（可跳过）
// 4. 完成提示

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var selectedTheme: AppThemeID = .midnight
    @State private var weReadAPIKey: String = ""
    @State private var enableClipboardMonitor = true
    @State private var enableSpotlight = true

    @Environment(\.themePalette) private var palette

    var body: some View {
        ZStack {
            // 当前主题背景
            PremiumBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部进度条
                progressBar

                // 步骤内容
                Group {
                    switch currentStep {
                    case 0: welcomeStep
                    case 1: themeStep
                    case 2: apiKeyStep
                    case 3: featuresStep
                    default: welcomeStep
                    }
                }
                .frame(maxWidth: 600)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 40)

                Spacer()

                // 底部按钮
                bottomButtons
                    .padding(20)
            }
        }
        .frame(width: 800, height: 540)
        .environment(ThemeStore.shared)
        .onAppear {
            selectedTheme = ThemeStore.shared.current
        }
    }

    // MARK: - 进度条

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(i <= currentStep ? Color.accentColor : Color.gray.opacity(0.25))
                    .frame(height: 3)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 30)
    }

    // MARK: - 步骤 1：欢迎

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .overlay(
                        MeshGradientBackground(colors: palette.meshColors, animated: true)
                            .clipShape(Circle())
                    )
                    .frame(width: 100, height: 100)
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: palette.accent.opacity(0.4), radius: 30, y: 12)

            Text("欢迎来到书摘温故")
                .font(.system(size: 32, weight: .bold))

            Text("一款为深度阅读者打造的笔记工作空间\n支持微信读书同步、AI 问答、间隔复习、多端导出")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.textSecondary)
                .lineSpacing(4)
        }
    }

    // MARK: - 步骤 2：主题

    private var themeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("选择你的主题")
                .font(.system(size: 24, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("切换会立即生效")
                .font(.system(size: 12))
                .foregroundStyle(palette.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(AppThemeID.allCases) { theme in
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTheme = theme
                            ThemeStore.shared.current = theme
                        }
                    } label: {
                        ThemePreviewPane(theme: theme)
                            .frame(height: 130)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        selectedTheme == theme ? Color.accentColor : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 步骤 3：API Key

    private var apiKeyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("配置微信读书")
                .font(.system(size: 24, weight: .bold))

            Text("可选 · 稍后可在设置里配置")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("微信读书 API Key")
                    .font(.system(size: 13, weight: .medium))
                SecureField("wrk- 开头的 Key", text: $weReadAPIKey)
                    .textFieldStyle(.roundedBorder)
                Text("从微信读书 Skill 服务获取 · wrk-xxxx 格式")
                    .font(.caption)
                    .foregroundStyle(palette.textTertiary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(palette.surface.opacity(0.5)))

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(palette.accent)
                Text("没有 Key 也能手动导入 TXT / Markdown / OCR 笔记")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    // MARK: - 步骤 4：功能开关

    private var featuresStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("启用这些功能")
                .font(.system(size: 24, weight: .bold))

            Toggle(isOn: $enableClipboardMonitor) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("剪贴板监听", systemImage: "doc.on.clipboard")
                        .font(.system(size: 13, weight: .semibold))
                    Text("复制文字时弹出'保存为笔记'气泡")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(palette.surface.opacity(0.5)))

            Toggle(isOn: $enableSpotlight) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Spotlight 索引", systemImage: "magnifyingglass.circle")
                        .font(.system(size: 13, weight: .semibold))
                    Text("系统 Spotlight 可搜索笔记")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(palette.surface.opacity(0.5)))

            // 提示
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(palette.warning)
                Text("随时可在设置里开启/关闭")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    // MARK: - 底部按钮

    private var bottomButtons: some View {
        HStack {
            if currentStep > 0 {
                Button("上一步") {
                    withAnimation { currentStep -= 1 }
                }
                .flatActionButton(height: 32)
            }

            Spacer()

            if currentStep < 3 {
                Button(currentStep == 2 ? "跳过" : "下一步") {
                    advance()
                }
                .flatActionButton(.accent, height: 32)
                .keyboardShortcut(.defaultAction)
            } else {
                Button("开始使用") {
                    finish()
                }
                .flatActionButton(.accent, height: 32)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    // MARK: - 动作

    private func advance() {
        withAnimation { currentStep += 1 }
    }

    private func finish() {
        // 保存 API Key
        if !weReadAPIKey.isEmpty {
            try? KeychainService.saveWeReadAPIKey(weReadAPIKey)
        }
        // 保存偏好
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(enableClipboardMonitor, forKey: "clipboardMonitorEnabled")
        UserDefaults.standard.set(enableSpotlight, forKey: "spotlightEnabled")

        ClipboardMonitor.shared.isEnabled = enableClipboardMonitor
        if enableClipboardMonitor {
            ClipboardMonitor.shared.startMonitoring()
        }

        dismiss()
    }

    private func paletteFor(_ id: AppThemeID) -> ThemePalette {
        switch id {
        case .midnight: return .midnight
        case .paper: return .paper
        case .ink: return .ink
        case .forest: return .forest
        }
    }
}

// MARK: - ThemePaletteKey 更新工具

extension ThemePaletteKey {
    /// 临时修改默认值（仅供 Onboarding 预览用，主 App 启动时由 themePalette() 注入）
    static func update(palette: ThemePalette) {
        // 注：实际上 EnvironmentKey 的 defaultValue 是静态的
        // 这里只能通过 .themePalette() 修饰符逐视图注入
        // 在 Onboarding 内部使用本地 state 模拟主题切换
        _ = palette
    }
}