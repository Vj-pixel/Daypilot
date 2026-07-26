// CanvasView.swift
// Canvas LMS integration — API token + institution domain approach

import SwiftUI
import SwiftData
import Security

// MARK: - Keychain Helper

private enum KeychainHelper {
    static func save(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      key,
            kSecValueData:        data,
            kSecAttrAccessible:   kSecAttrAccessibleWhenUnlocked
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData:  kCFBooleanTrue!,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(forKey key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Canvas Data Models

struct CanvasCourse: Codable, Identifiable {
    let id: Int
    let name: String
}

struct CanvasAssignment: Codable, Identifiable {
    let id: Int
    let name: String
    let due_at: String?
    let points_possible: Double?
    let assignment_group_id: Int?

    var courseId: Int = 0
    var courseName: String = ""
    var gradeWeight: Double? = nil  // filled in from assignment group after fetch

    enum CodingKeys: String, CodingKey {
        case id, name, due_at, points_possible, assignment_group_id
    }
}

struct CanvasAssignmentGroup: Codable, Identifiable {
    let id: Int
    let name: String
    let group_weight: Double?
}

// MARK: - Canvas Service

actor CanvasService {
    static let shared = CanvasService()
    private init() {}

    func fetchCourses(domain: String, token: String) async throws -> [CanvasCourse] {
        var all: [CanvasCourse] = []
        var next: URL? = URL(string: "https://\(domain)/api/v1/courses?enrollment_state=active&per_page=100")
        while let url = next {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateResponse(response)
            all += try JSONDecoder().decode([CanvasCourse].self, from: data)
            next = (response as? HTTPURLResponse).flatMap {
                parseNextLink(from: $0.value(forHTTPHeaderField: "Link") ?? "")
            }
        }
        return all
    }

    func fetchAssignments(domain: String, token: String, courseId: Int) async throws -> [CanvasAssignment] {
        var all: [CanvasAssignment] = []
        var next: URL? = URL(string: "https://\(domain)/api/v1/courses/\(courseId)/assignments?per_page=100&order_by=due_at")
        while let url = next {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateResponse(response)
            all += try JSONDecoder().decode([CanvasAssignment].self, from: data)
            next = (response as? HTTPURLResponse).flatMap {
                parseNextLink(from: $0.value(forHTTPHeaderField: "Link") ?? "")
            }
        }
        return all
    }

    func fetchAssignmentGroups(domain: String, token: String, courseId: Int) async throws -> [CanvasAssignmentGroup] {
        guard let url = URL(string: "https://\(domain)/api/v1/courses/\(courseId)/assignment_groups?per_page=100") else { return [] }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return (try? JSONDecoder().decode([CanvasAssignmentGroup].self, from: data)) ?? []
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode == 401 { throw CanvasError.unauthorized }
        if http.statusCode == 404 { throw CanvasError.notFound }
        if !(200..<300).contains(http.statusCode) { throw CanvasError.serverError(http.statusCode) }
    }

    private func parseNextLink(from header: String) -> URL? {
        for part in header.components(separatedBy: ",") {
            let segs = part.components(separatedBy: ";")
            guard segs.count >= 2 else { continue }
            if segs[1].trimmingCharacters(in: .whitespaces) == "rel=\"next\"" {
                let raw = segs[0]
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
                return URL(string: raw)
            }
        }
        return nil
    }
}

enum CanvasError: LocalizedError {
    case unauthorized
    case notFound
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Invalid API token. Please check your credentials in settings."
        case .notFound:     return "Canvas domain not found. Please check your institution URL."
        case .serverError(let code): return "Server error (\(code)). Please try again."
        }
    }
}

// MARK: - Time Filter

enum CanvasTimeFilter: String, CaseIterable {
    case all, today, week, month

    var label: String {
        switch self {
        case .all:   return "All"
        case .today: return "Today"
        case .week:  return "Week"
        case .month: return "Month"
        }
    }
}

// MARK: - Canvas Setup View

struct CanvasSetupView: View {
    @AppStorage("canvasDomain") private var domain: String = ""
    var onConnect: (String) -> Void

    @State private var localDomain: String = ""
    @State private var localToken: String = ""
    @State private var showError = false

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Text("Connect Canvas LMS")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Enter your institution's Canvas domain and a personal access token to import your assignments.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Institution Domain")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white.opacity(0.7))
                    TextField("e.g. canvas.university.edu", text: $localDomain)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Access Token")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white.opacity(0.7))
                    SecureField("Paste your Canvas API token", text: $localToken)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    Text("Generate a token in Canvas → Account → Settings → New Access Token")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.45))
                }
            }

            Button {
                let cleanDomain = localDomain.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanToken = localToken.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleanDomain.isEmpty, !cleanToken.isEmpty else {
                    showError = true; return
                }
                domain = cleanDomain
                KeychainHelper.save(cleanToken, forKey: "canvasToken")
                onConnect(cleanToken)
            } label: {
                Text("Connect")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding(24)
        .onAppear {
            localDomain = domain
            localToken = KeychainHelper.load(forKey: "canvasToken") ?? ""
        }
        .alert("Please enter both a domain and an access token.", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        }
    }
}

// MARK: - Assignment Row

struct CanvasAssignmentRow: View {
    let assignment: CanvasAssignment
    let isImported: Bool
    let onImport: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.name)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let due = parsedDue {
                        Text("Due: \(due.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(dueColor(for: due))
                    } else {
                        Text("No due date")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let weight = assignment.gradeWeight, weight > 0 {
                        Text("·")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(weight))% of grade")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.purple.opacity(0.85))
                    }
                }
            }
            Spacer()
            Button(isImported ? "Imported" : "Import") {
                onImport()
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isImported ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
            .foregroundColor(isImported ? .green : .blue)
            .cornerRadius(8)
            .disabled(isImported)
            .animation(.easeInOut(duration: 0.2), value: isImported)
        }
        .padding(.vertical, 4)
    }

    private var parsedDue: Date? {
        guard let str = assignment.due_at else { return nil }
        return ISO8601DateFormatter().date(from: str)
    }

    private func dueColor(for date: Date) -> Color {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 99
        if days <= 2 { return .red }
        if days <= 7 { return .orange }
        return .secondary
    }
}

// MARK: - Main Canvas View

struct CanvasView: View {
    @AppStorage("canvasDomain") private var domain: String = ""
    // Token is stored in Keychain, not UserDefaults
    @State private var token: String = KeychainHelper.load(forKey: "canvasToken") ?? ""
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var gradientManager: SunsetGradientManager

    @State private var assignments: [CanvasAssignment] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSetup = false
    @State private var timeFilter: CanvasTimeFilter = .all
    @State private var expandedCourses: Set<Int> = []
    @State private var importedIds: Set<Int> = []
    @State private var pendingImport: CanvasAssignment? = nil

    private var isConnected: Bool { !domain.isEmpty && !token.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Rectangle().fill(gradientManager.gradient).ignoresSafeArea()
                ThemeParticleView().ignoresSafeArea().allowsHitTesting(false)

                Group {
                    if !isConnected || showSetup {
                        ScrollView {
                            CanvasSetupView { newToken in
                                token = newToken
                                showSetup = false
                                Task { await loadData() }
                            }
                        }
                    } else if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.4)
                            Text("Loading Canvas…")
                                .foregroundColor(.white.opacity(0.8))
                        }
                    } else if let errorMessage {
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            Button("Retry") { Task { await loadData() } }
                                .buttonStyle(.bordered)
                                .tint(.white)
                            Button("Change Credentials") { showSetup = true }
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    } else if assignments.isEmpty {
                        ContentUnavailableView("No Assignments Found", systemImage: "tray")
                            .foregroundColor(.white)
                    } else {
                        assignmentList
                    }
                }
            }
            .navigationTitle("Canvas")
            .toolbarColorScheme(.dark)
            .toolbar {
                if isConnected && !showSetup {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { showSetup = true } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
            .sheet(item: $pendingImport) { assignment in
                ImportDateSheet(
                    assignment: assignment,
                    assignmentDate: assignment.due_at.flatMap { ISO8601DateFormatter().date(from: $0) }
                ) { selectedDate in
                    importAsTask(assignment, dueDate: selectedDate)
                    importedIds.insert(assignment.id)
                    pendingImport = nil
                }
            }
        }
        .task {
            if isConnected && !showSetup { await loadData() }
        }
    }

    private var filteredAssignments: [CanvasAssignment] {
        let cal = Calendar.current
        let now = Date()
        switch timeFilter {
        case .all:
            return assignments
        case .today:
            return assignments.filter { a in
                guard let s = a.due_at, let d = ISO8601DateFormatter().date(from: s) else { return false }
                return cal.isDate(d, inSameDayAs: now)
            }
        case .week:
            guard let interval = cal.dateInterval(of: .weekOfYear, for: now) else { return assignments }
            return assignments.filter { a in
                guard let s = a.due_at, let d = ISO8601DateFormatter().date(from: s) else { return false }
                return d >= interval.start && d < interval.end
            }
        case .month:
            guard let interval = cal.dateInterval(of: .month, for: now) else { return assignments }
            return assignments.filter { a in
                guard let s = a.due_at, let d = ISO8601DateFormatter().date(from: s) else { return false }
                return d >= interval.start && d < interval.end
            }
        }
    }

    private var assignmentList: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $timeFilter) {
                ForEach(CanvasTimeFilter.allCases, id: \.self) { f in
                    Text(f.label).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            let courseIds = groupedCourseIds(from: filteredAssignments)
            if courseIds.isEmpty {
                ContentUnavailableView("No Assignments", systemImage: "tray")
                    .foregroundColor(.white)
                    .padding(.top, 40)
            } else {
                List {
                    ForEach(courseIds, id: \.self) { courseId in
                        let courseAssignments = filteredAssignments.filter { $0.courseId == courseId }
                        let courseName = courseAssignments.first?.courseName ?? "Course \(courseId)"
                        let isExpanded = expandedCourses.contains(courseId)

                        Section {
                            if isExpanded {
                                ForEach(courseAssignments) { assignment in
                                    CanvasAssignmentRow(
                                        assignment: assignment,
                                        isImported: importedIds.contains(assignment.id)
                                    ) {
                                        pendingImport = assignment
                                    }
                                }
                            }
                        } header: {
                            Button {
                                if isExpanded {
                                    expandedCourses.remove(courseId)
                                } else {
                                    expandedCourses.insert(courseId)
                                }
                            } label: {
                                HStack {
                                    Text(courseName)
                                        .foregroundColor(.white.opacity(0.75))
                                        .font(.caption.weight(.semibold))
                                        .textCase(nil)
                                    Spacer()
                                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
        }
    }

    private func groupedCourseIds(from list: [CanvasAssignment]) -> [Int] {
        var seen = Set<Int>()
        return list.compactMap { a -> Int? in
            guard !seen.contains(a.courseId) else { return nil }
            seen.insert(a.courseId)
            return a.courseId
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            let courses = try await CanvasService.shared.fetchCourses(domain: domain, token: token)
            var allAssignments: [CanvasAssignment] = []
            for course in courses {
                var courseAssignments = try await CanvasService.shared.fetchAssignments(
                    domain: domain, token: token, courseId: course.id
                )
                let groups = try await CanvasService.shared.fetchAssignmentGroups(
                    domain: domain, token: token, courseId: course.id
                )
                let groupWeights = Dictionary(uniqueKeysWithValues: groups.compactMap { g -> (Int, Double)? in
                    guard let w = g.group_weight, w > 0 else { return nil }
                    return (g.id, w)
                })
                for i in courseAssignments.indices {
                    courseAssignments[i].courseId = course.id
                    courseAssignments[i].courseName = course.name
                    if let gid = courseAssignments[i].assignment_group_id {
                        courseAssignments[i].gradeWeight = groupWeights[gid]
                    }
                }
                allAssignments.append(contentsOf: courseAssignments)
            }
            await MainActor.run {
                let fmt = ISO8601DateFormatter()
                assignments = allAssignments.sorted { a, b in
                    let d0 = a.due_at.flatMap { fmt.date(from: $0) } ?? Date.distantFuture
                    let d1 = b.due_at.flatMap { fmt.date(from: $0) } ?? Date.distantFuture
                    return d0 < d1
                }
                expandedCourses = Set(groupedCourseIds(from: assignments))
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func importAsTask(_ assignment: CanvasAssignment, dueDate: Date?) {
        let urgency: UrgencyLevel = {
            guard let due = dueDate else { return .notUrgent }
            let days = max(0, Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 99)
            let daysScore = max(0.0, 1.0 - Double(days) / 14.0)
            let weightScore = (assignment.gradeWeight ?? 0.0) / 100.0
            let priority = daysScore * 0.7 + weightScore * 0.3
            if priority > 0.6 { return .urgent }
            if priority > 0.3 { return .kindaUrgent }
            return .notUrgent
        }()
        let title = assignment.courseName.isEmpty
            ? assignment.name
            : "[\(assignment.courseName)] \(assignment.name)"
        let task = Daypilot(title: title, dueDate: dueDate, urgency: urgency)
        task.sourceTag = "Canvas"
        modelContext.insert(task)
        try? modelContext.save()
    }
}

// MARK: - Import Date Sheet

struct ImportDateSheet: View {
    let assignment: CanvasAssignment
    let assignmentDate: Date?
    let onImport: (Date?) -> Void

    @State private var customDate: Date = Date()
    @State private var showDatePicker = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.85).ignoresSafeArea()

                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 8) {
                        if !assignment.courseName.isEmpty {
                            Text(assignment.courseName)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white.opacity(0.55))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.white.opacity(0.1)))
                        }
                        Text(assignment.name)
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 8)

                    // Option buttons
                    VStack(spacing: 12) {
                        importButton(
                            icon: "calendar.badge.clock",
                            title: "Import for Today",
                            subtitle: Date().formatted(date: .abbreviated, time: .omitted),
                            color: .blue
                        ) {
                            onImport(Calendar.current.startOfDay(for: Date()))
                            dismiss()
                        }

                        if let date = assignmentDate {
                            importButton(
                                icon: "books.vertical",
                                title: "Use Assignment Date",
                                subtitle: date.formatted(date: .abbreviated, time: .shortened),
                                color: Color(red: 0.88, green: 0.28, blue: 0.08)
                            ) {
                                onImport(date)
                                dismiss()
                            }
                        }

                        VStack(spacing: 10) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { showDatePicker.toggle() }
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 18))
                                        .foregroundColor(.purple)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Choose a Date")
                                            .font(.body.weight(.semibold))
                                            .foregroundColor(.white)
                                        Text(customDate.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.55))
                                    }
                                    Spacer()
                                    Image(systemName: showDatePicker ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)

                            if showDatePicker {
                                DatePicker("", selection: $customDate, displayedComponents: .date)
                                    .datePickerStyle(.graphical)
                                    .tint(.purple)
                                    .colorScheme(.dark)
                                    .transition(.opacity.combined(with: .move(edge: .top)))

                                Button {
                                    onImport(customDate)
                                    dismiss()
                                } label: {
                                    Text("Import on \(customDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.body.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.purple)
                                        .foregroundColor(.white)
                                        .cornerRadius(14)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }

    @ViewBuilder
    private func importButton(icon: String, title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(color.opacity(0.7))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(color.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(color.opacity(0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
