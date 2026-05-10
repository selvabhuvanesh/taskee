//
//  RoleSelectionView.swift
//  Taskee
//
//  Created by Selva Bhuvanesh on 4/25/26.
//

import SwiftUI
import SwiftData
import PhotosUI

struct RoleSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var selectedRole = ""
    @State private var name = ""
    @State private var inviteCode = ""
    @State private var selectedAvatar = "av01"
    @State private var joinExisting = false
    @State private var isValidating = false
    @State private var showInvalidCode = false
    @State private var showCloudUnavailable = false
    @State private var showAlreadyHasFamily = false
    @State private var existingFamilyCode = ""
    @State private var showFamilyFull = false
    @State private var parentalConsentPassed = false
    @State private var gateAnswer = ""
    @State private var gateA = Int.random(in: 6...12)
    @State private var gateB = Int.random(in: 4...9)
    @State private var showWrongAnswer = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var customPhotoImage: UIImage?

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
                    } else if !parentalConsentPassed {
                        parentalGateView
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
                Image(systemName: "person.3.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(calmAccent)

                Text("Welcome to taskoot!")
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
            } else if !parentalConsentPassed {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.orange)

                Text("Parent Verification")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("A parent or guardian must verify and consent before a child can use taskoot.")
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose Avatar")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

            HStack(spacing: 16) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    VStack(spacing: 6) {
                        if let img = customPhotoImage, selectedAvatar.hasPrefix("photo_") {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 54, height: 54)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .strokeBorder(.blue, lineWidth: 2.5)
                                        .frame(width: 58, height: 58)
                                )
                        } else {
                            ZStack {
                                Circle()
                                    .fill(.white.opacity(0.15))
                                    .frame(width: 54, height: 54)
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        Text("Photo")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .onChange(of: selectedPhotoItem) { _, item in
                    guard let item else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            let photoID = UUID().uuidString
                            let resized = resizeAvatar(uiImage, maxSize: 400)
                            if saveAvatarPhoto(resized, photoID: photoID) {
                                customPhotoImage = resized
                                selectedAvatar = "photo_\(photoID)"
                            }
                        }
                    }
                }

                Spacer()
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(avatarPresets, id: \.id) { preset in
                    Button {
                        selectedAvatar = preset.id
                        customPhotoImage = nil
                    } label: {
                        AvatarFaceView(config: preset, size: 54)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        selectedAvatar == preset.id ? preset.bgColor : .clear,
                                        lineWidth: 2.5
                                    )
                                    .frame(width: 58, height: 58)
                            )
                    }
                }
            }

            Text("Animals")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(animalAvatarPresets, id: \.id) { preset in
                    Button {
                        selectedAvatar = preset.id
                        customPhotoImage = nil
                    } label: {
                        AnimalAvatarFaceView(config: preset, size: 54)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        selectedAvatar == preset.id ? preset.bgColor : .clear,
                                        lineWidth: 2.5
                                    )
                                    .frame(width: 58, height: 58)
                            )
                    }
                }
            }
        }
    }

    private func resizeAvatar(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let scale = min(maxSize / image.size.width, maxSize / image.size.height, 1.0)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
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
                if isNew {
                    await cloudKitManager.createFamilyZone(familyCode: code)
                } else {
                    await cloudKitManager.ensureFamilyZoneAccess(familyCode: code, appleUserID: authManager.appleUserID)
                    await cloudKitManager.syncAll(context: modelContext, familyCode: code)
                }
                if let familyTier = await cloudKitManager.fetchFamilyTier(familyCode: code) {
                    subscriptionManager.setFamilyTier(familyTier)
                }
                await cloudKitManager.setupSubscriptions(familyCode: code, appleUserID: authManager.appleUserID, role: "parent")
            } else {
                modelContext.delete(member)
                showCloudUnavailable = true
            }
        }
    }

    private var parentalGateView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("Please ask your parent or guardian to answer this question:")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                Text("What is \(gateA) × \(gateB)?")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)

                TextField("Enter answer", text: $gateAnswer)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .padding(14)
                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    )
                    .frame(width: 160)
            }
            .padding(24)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("Parent/Guardian Consent")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("By proceeding, you confirm that you are the parent or legal guardian of this child and consent to the following:")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))

                VStack(alignment: .leading, spacing: 8) {
                    consentBullet("Your child's name and task activity will be stored securely in your family's private cloud space")
                    consentBullet("Task data is shared only within your family group")
                    consentBullet("No third-party tracking or advertising is used")
                    consentBullet("You can delete your child's data at any time by removing them from the family")
                }
            }
            .padding(18)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            )

            HStack(spacing: 12) {
                Link("Privacy Policy", destination: privacyPolicyURL)
                Text("·").foregroundStyle(.white.opacity(0.3))
                Link("Terms of Use", destination: termsOfUseURL)
            }
            .font(.caption)
            .tint(.white.opacity(0.5))

            Button {
                if Int(gateAnswer) == gateA * gateB {
                    withAnimation(.snappy) { parentalConsentPassed = true }
                } else {
                    showWrongAnswer = true
                    gateA = Int.random(in: 6...12)
                    gateB = Int.random(in: 4...9)
                    gateAnswer = ""
                }
            } label: {
                Text("I Consent — Continue")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        gateAnswer.isEmpty
                            ? AnyShapeStyle(.white.opacity(0.1))
                            : AnyShapeStyle(.orange),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .foregroundStyle(.white)
            }
            .disabled(gateAnswer.isEmpty)

            Button {
                withAnimation(.snappy) { selectedRole = "" }
            } label: {
                Text("Back")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .alert("Incorrect Answer", isPresented: $showWrongAnswer) {
            Button("Try Again", role: .cancel) { }
        } message: {
            Text("Please ask a parent or guardian to answer the question to continue.")
        }
    }

    private func consentBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
                .padding(.top, 1)
            Text(text)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
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
                            isAccepted: false,
                            appleUserID: authManager.appleUserID
                        )
                        modelContext.insert(member)
                        let pushed = await cloudKitManager.pushMember(member, familyCode: code)
                        if pushed {
                            authManager.userName = trimmedName
                            authManager.isPendingApproval = true
                            authManager.role = "child"
                            authManager.familyCode = code
                            authManager.avatar = selectedAvatar
                            if let familyTier = await cloudKitManager.fetchFamilyTier(familyCode: code) {
                                subscriptionManager.setFamilyTier(familyTier)
                            }
                            await cloudKitManager.setupSubscriptions(familyCode: code, appleUserID: authManager.appleUserID, role: "child")
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
