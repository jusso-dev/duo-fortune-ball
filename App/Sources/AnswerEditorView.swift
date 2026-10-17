import SwiftUI
import FortuneCore

/// Add, edit, reorder, remove and reset answers. Changes save immediately.
struct AnswerEditorView: View {
    let model: FortuneModel
    @State private var newText = ""
    @State private var newTone: AnswerTone = .yes
    @State private var confirmingReset = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Add an answer") {
                    TextField("Your answer", text: $newText)
                    Picker("Tone", selection: $newTone) {
                        ForEach(AnswerTone.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    Button("Add") {
                        model.editAnswers { try $0.add(newText, tone: newTone) }
                        if model.lastError == nil { newText = "" }
                    }
                    .disabled(newText.trimmingCharacters(in: .whitespaces).isEmpty)
                    if let error = model.lastError {
                        Text(error.message).font(.footnote).foregroundStyle(Palette.ochre)
                    }
                    if model.saveFailed {
                        Text("Couldn't save your answers. Your changes will be lost when the app closes.")
                            .font(.footnote)
                            .foregroundStyle(Palette.ochre)
                    }
                }
                Section("Answers") {
                    ForEach(model.answerSet.answers) { answer in
                        HStack {
                            Text(answer.text)
                            Spacer()
                            Text(answer.tone.label).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { model.answerSet.answers[$0].id }
                        model.editAnswers { set in for id in ids { try set.remove(id: id) } }
                    }
                    .onMove { source, destination in
                        model.editAnswers { $0.move(fromOffsets: source, toOffset: destination) }
                    }
                }
                Section {
                    Button("Reset to original answers", role: .destructive) {
                        confirmingReset = true
                    }
                    .confirmationDialog(
                        "Reset to the original answers?",
                        isPresented: $confirmingReset,
                        titleVisibility: .visible
                    ) {
                        Button("Reset answers", role: .destructive) {
                            model.editAnswers { $0.resetToOriginal() }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Your own answers will be removed. A copy of the current set is kept as a backup.")
                    }
                }
            }
            .navigationTitle("Answers")
            .toolbar {
                EditButton()
                Button("Done") { dismiss() }
            }
        }
    }
}

extension AnswerTone {
    var label: String {
        switch self {
        case .yes: "Yes"
        case .maybe: "Maybe"
        case .no: "No"
        case .playful: "Playful"
        }
    }
}

extension AnswerSetError {
    var message: String {
        switch self {
        case .emptyText: "Answers cannot be empty."
        case .textTooLong(let max): "Keep answers to \(max) characters or fewer."
        case .duplicate: "That answer is already in the list."
        case .notFound: "That answer no longer exists."
        case .wouldBeEmpty: "Keep at least one answer."
        }
    }
}
