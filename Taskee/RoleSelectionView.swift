//
//  RoleSelectionView.swift
//  Taskee
//
//  Created by Selva Bhuvanesh on 4/25/26.
//

import SwiftUI
import SwiftData

struct RoleSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var selectedRole = ""
    @State private var name = ""
    @State private var inviteCode = ""
    @State private var selectedAvatar = "star.fill"
    @State private var joinExisting = false
    @State private var isValidating = false
    @State private var showInvalidCode = false
    @State private var showCloudUnavailable = false
    @State private var showAlreadyHasFamily = false
    @State private var existingFamilyCode = ""
    @State private var showFamilyFull = false

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    header

                    Spacer().frame(height: 40)

                    if selectedRole.isEmpty {
                        roleCards
                    } else if selectedRole == "parent" {
                        parentSetup
                    } else {
                        childSetup
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 28)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            if selectedRole.isEmpty {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(calmAccent)

                Text("Welcome to Taskee!")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("Let's get you set up. Are you a parent managing tasks or a child completing them?")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            } else if selectedRole == "parent" {
                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(calmAccent)

                Text("Parent Setup")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("Create your family or join an existing one. Once set up, you'll get an invite code to share with your family members so they can join too!")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "figure.child")
                    .font(.system(size: 52))
                    .foregroundStyle(calmAccent)

                Text("Join Your Family")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("Enter your name and the invite code from your parent to join your family and start completing tasks!")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .animation(.snappy, value: selectedRole)
    }

    private var roleCards: some View {
        VStack(spacing: 16) {
            roleCard(
                title: "Parent",
                subtitle: "Create tasks and assign to your children",
                icon: "person.badge.shield.checkmark.fill",
                role: "parent"
            )

            roleCard(
                title: "Child",
                subtitle: "View and complete tasks assigned by parent",
                icon: "figure.child",
                role: "child"
            )
        }
    }

    private func roleCard(title: String, subtitle: String, icon: String, role: String) -> some View {
        Button {
            withAnimation(.snappy) {
                selectedRole = role
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(calmAccent)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(18)
            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    private var avatarPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose Avatar")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                ForEach(avatarOptions, id: \.self) { avatar in
                    Button {
                        selectedAvatar = avatar
                    } label: {
                        Image(systemName: avatar)
                            .font(.system(size: 32))
                            .frame(width: 54, height: 54)
                            .background(
                                selectedAvatar == avatar ? avatarColor(for: avatar).opacity(0.3) : .white.opacity(0.15),
                                in: Circle()
                            )
                            .foregroundStyle(selectedAvatar == avatar ? avatarColor(for: avatar) : .white.opacity(0.6))
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        selectedAvatar == avatar ? avatarColor(for: avatar) : .clear,
                                        lineWidth: 2
                                    )
                            )
                    }
                }
            }
        }
    }

    private var parentSetup: some View {
        VStack(spacing: 20) {
            avatarPicker

            VStack(alignment: .leading, spacing: 8) {
                Text("Your Name")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))

                TextField("Enter your name", text: $name)
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    )
            }

            VStack(spacing: 12) {
                Button {
                    withAnimation(.snappy) { joinExisting = false }
                } label: {
                    HStack {
                        Image(systemName: joinExisting ? "circle" : "checkmark.circle.fill")
                            .foregroundStyle(joinExisting ? .white.opacity(0.3) : calmAccent)
                        Text("Create New Family")
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .font(.subheadline)
                    .padding(12)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    withAnimation(.snappy) { joinExisting = true }
                } label: {
                    HStack {
                        Image(systemName: joinExisting ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(joinExisting ? calmAccent : .white.opacity(0.3))
                        Text("Join Existing Family")
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .font(.subheadline)
                    .padding(12)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }
            }

            if joinExisting {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Family Invite Code")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))

                    TextField("e.g. ABC123", text: $inviteCode)
                        .font(.body)
                        .foregroundStyle(.white)
                        .textInputAutocapitalization(.characters)
                        .padding(14)
                        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        )
                }
            }

            Button {
                let trimmedName = name.trimmingCharacters(in: .whitespaces)
                if joinExisting {
                    isValidating = true
                    Task {
                        let result = await cloudKitManager.validateFamilyCode(inviteCode.uppercased())
                        isValidating = false
                        switch result {
                        case .valid:
                            let count = await cloudKitManager.memberCount(familyCode: inviteCode.uppercased())
                            guard count < subscriptionManager.maxMembers else {
                                showFamilyFull = true
                                return
                            }
                            completeParentSetup(name: trimmedName, code: inviteCode.uppercased(), isNew: false)
                        case .invalid:
                            showInvalidCode = true
                        case .cloudUnavailable:
                            showCloudUnavailable = true
                        }
                    }
                } else {
                    isValidating = true
                    Task {
                        if let existing = await cloudKitManager.familyAlreadyExists(appleUserID: authManager.appleUserID) {
                            isValidating = false
                            existingFamilyCode = existing
                            showAlreadyHasFamily = true
                            return
                        }
                        authManager.generateFamilyCode()
                        let code = authManager.familyCode
                        let saved = await cloudKitManager.registerFamily(code: code, createdBy: trimmedName, appleUserID: authManager.appleUserID)
                        isValidating = false
                        if saved {
                            completeParentSetup(name: trimmedName, code: code, isNew: true)
                        } else {
                            showCloudUnavailable = true
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if isValidating {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(joinExisting ? "Join as Parent" : "Create Family")
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    isParentFormValid && !isValidating
                        ? AnyShapeStyle(calmAccent)
                        : AnyShapeStyle(.white.opacity(0.1)),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .foregroundStyle(.white)
            }
            .disabled(!isParentFormValid || isValidating)

            Button {
                withAnimation(.snappy) { selectedRole = "" }
            } label: {
                Text("Back")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .alert("Invalid Family Code", isPresented: $showInvalidCode) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("No family exists with that invite code. Please check the code and try again.")
        }
        .alert("Connection Error", isPresented: $showCloudUnavailable) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(cloudKitManager.lastSyncError ?? "Unable to connect. Please check your internet connection and try again.")
        }
        .alert("Family Already Exists", isPresented: $showAlreadyHasFamily) {
            Button("Use Existing Family") {
                let trimmedName = name.trimmingCharacters(in: .whitespaces)
                completeParentSetup(name: trimmedName, code: existingFamilyCode, isNew: false)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You already have a family with code \(existingFamilyCode). You can use your existing family or join another family with an invite code.")
        }
        .alert("Family Full", isPresented: $showFamilyFull) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This family has reached the maximum number of members (\(subscriptionManager.maxMembers)) for the current plan.")
        }
    }

    private func completeParentSetup(name: String, code: String, isNew: Bool) {
        let member = FamilyMember(
            name: name,
            memberRole: "parent",
            avatar: selectedAvatar,
            appleUserID: authManager.appleUserID
        )
        modelContext.insert(member)
        Task {
            let pushed = await cloudKitManager.pushMember(member, familyCode: code)
            if pushed {
                authManager.userName = name
                authManager.role = "parent"
                authManager.avatar = selectedAvatar
                authManager.familyCode = code
                if !isNew {
                    await cloudKitManager.syncAll(context: modelContext, familyCode: code)
                }
                await cloudKitManager.setupSubscriptions(familyCode: code)
            } else {
                modelContext.delete(member)
                showCloudUnavailable = true
            }
        }
    }

    private var childSetup: some View {
        VStack(spacing: 20) {
            avatarPicker

            VStack(alignment: .leading, spacing: 8) {
                Text("Your Name")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))

                TextField("Enter your name", text: $name)
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Family Invite Code")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))

                TextField("e.g. ABC123", text: $inviteCode)
                    .font(.body)
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.characters)
                    .padding(14)
                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    )
            }

            Button {
                let trimmedName = name.trimmingCharacters(in: .whitespaces)
                let code = inviteCode.uppercased()
                isValidating = true
                Task {
                    let result = await cloudKitManager.validateFamilyCode(code)
                    isValidating = false
                    switch result {
                    case .invalid:
                        showInvalidCode = true
                    case .cloudUnavailable:
                        showCloudUnavailable = true
                    case .valid:
                        let count = await cloudKitManager.memberCount(familyCode: code)
                        guard count < subscriptionManager.maxMembers else {
                            showFamilyFull = true
                            return
                        }
                        let member = FamilyMember(
                            name: trimmedName,
                            memberRole: "child",
                            avatar: selectedAvatar,
                            appleUserID: authManager.appleUserID
                        )
                        modelContext.insert(member)
                        let pushed = await cloudKitManager.pushMember(member, familyCode: code)
                        if pushed {
                            authManager.userName = trimmedName
                            authManager.role = "child"
                            authManager.familyCode = code
                            authManager.avatar = selectedAvatar
                            await cloudKitManager.syncAll(context: modelContext, familyCode: code)
                            await cloudKitManager.setupSubscriptions(familyCode: code)
                        } else {
                            modelContext.delete(member)
                            showCloudUnavailable = true
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if isValidating {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Join Family")
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    isChildFormValid && !isValidating
                        ? AnyShapeStyle(calmAccent)
                        : AnyShapeStyle(.white.opacity(0.1)),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .foregroundStyle(.white)
            }
            .disabled(!isChildFormValid || isValidating)

            Button {
                withAnimation(.snappy) { selectedRole = "" }
            } label: {
                Text("Back")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .alert("Invalid Family Code", isPresented: $showInvalidCode) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("No family exists with that invite code. Please check the code and try again.")
        }
        .alert("Connection Error", isPresented: $showCloudUnavailable) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(cloudKitManager.lastSyncError ?? "Unable to connect. Please check your internet connection and try again.")
        }
        .alert("Family Full", isPresented: $showFamilyFull) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This family has reached the maximum number of members (\(subscriptionManager.maxMembers)) for the current plan.")
        }
    }

    private var isParentFormValid: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespaces).isEmpty
        if joinExisting {
            return hasName && inviteCode.trimmingCharacters(in: .whitespaces).count >= 6
        }
        return hasName
    }

    private var isChildFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        inviteCode.trimmingCharacters(in: .whitespaces).count >= 6
    }
}

#Preview {
    RoleSelectionView()
        .modelContainer(for: [Item.self, FamilyMember.self], inMemory: true)
        .environment(AuthManager())
        .environment(CloudKitManager())
        .environment(SubscriptionManager())
}
