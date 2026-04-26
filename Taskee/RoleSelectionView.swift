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
    @State private var selectedRole = ""
    @State private var name = ""
    @State private var inviteCode = ""
    @State private var selectedAvatar = "person.circle.fill"
    @State private var joinExisting = false

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
            Image(systemName: "person.2.fill")
                .font(.system(size: 52))
                .foregroundStyle(.blue)

            Text("Choose Your Role")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text("Are you setting up tasks or completing them?")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
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
                    .foregroundStyle(.blue)
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
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
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
                            .font(.system(size: 28))
                            .frame(width: 48, height: 48)
                            .background(
                                selectedAvatar == avatar ? .blue.opacity(0.3) : .white.opacity(0.08),
                                in: Circle()
                            )
                            .foregroundStyle(selectedAvatar == avatar ? .blue : .white.opacity(0.6))
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        selectedAvatar == avatar ? .blue : .clear,
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
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
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
                            .foregroundStyle(joinExisting ? .white.opacity(0.3) : .blue)
                        Text("Create New Family")
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .font(.subheadline)
                    .padding(12)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    withAnimation(.snappy) { joinExisting = true }
                } label: {
                    HStack {
                        Image(systemName: joinExisting ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(joinExisting ? .blue : .white.opacity(0.3))
                        Text("Join Existing Family")
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .font(.subheadline)
                    .padding(12)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
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
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        )
                }
            }

            Button {
                let trimmedName = name.trimmingCharacters(in: .whitespaces)
                authManager.userName = trimmedName
                authManager.role = "parent"
                authManager.avatar = selectedAvatar
                if joinExisting {
                    authManager.familyCode = inviteCode.uppercased()
                } else {
                    authManager.generateFamilyCode()
                }
                let member = FamilyMember(
                    name: trimmedName,
                    memberRole: "parent",
                    avatar: selectedAvatar
                )
                modelContext.insert(member)
            } label: {
                Text(joinExisting ? "Join as Parent" : "Create Family")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        isParentFormValid
                            ? AnyShapeStyle(.blue)
                            : AnyShapeStyle(.white.opacity(0.1)),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .foregroundStyle(.white)
            }
            .disabled(!isParentFormValid)

            Button {
                withAnimation(.snappy) { selectedRole = "" }
            } label: {
                Text("Back")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
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
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
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
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    )
            }

            Button {
                let trimmedName = name.trimmingCharacters(in: .whitespaces)
                authManager.userName = trimmedName
                authManager.role = "child"
                authManager.familyCode = inviteCode.uppercased()
                authManager.avatar = selectedAvatar
                let member = FamilyMember(
                    name: trimmedName,
                    memberRole: "child",
                    avatar: selectedAvatar
                )
                modelContext.insert(member)
            } label: {
                Text("Join Family")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        isChildFormValid
                            ? AnyShapeStyle(.blue)
                            : AnyShapeStyle(.white.opacity(0.1)),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .foregroundStyle(.white)
            }
            .disabled(!isChildFormValid)

            Button {
                withAnimation(.snappy) { selectedRole = "" }
            } label: {
                Text("Back")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
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
}
