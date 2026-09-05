import SwiftUI

struct NotesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editing: Note?
    var body: some View {
        List {
            ForEach(model.life.notes.sorted { $0.updatedAt > $1.updatedAt }) { note in
                Button { editing = note } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(note.displayTitle).font(.headline).foregroundStyle(.primary)
                        Text(note.body).lineLimit(2).foregroundStyle(.secondary)
                        Text(note.updatedAt, format: .dateTime.month().day()).font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }
            }
        }
        .overlay { if model.life.notes.isEmpty { ContentUnavailableView("A place for your thoughts", systemImage: "note.text", description: Text("Tap + to write a note.")) } }
        .navigationTitle("Notes")
        .toolbar { Button { editing = Note() } label: { Image(systemName: "plus") }.accessibilityLabel("Create note").disabled(!model.lifeReady) }
        .sheet(item: $editing) { NoteEditor(note: $0).environmentObject(model) }
    }
}

private struct NoteEditor: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State var note: Note
    @State private var confirmingDelete = false
    private var existing: Bool { model.life.notes.contains { $0.id == note.id } }
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Title", text: $note.title).font(.title2.bold())
                TextEditor(text: $note.body).accessibilityLabel("Note text").scrollContentBackground(.hidden)
                Text("Tap Save to keep your changes.").font(.caption).foregroundStyle(.secondary)
                if existing { Button("Delete note", role: .destructive) { confirmingDelete = true } }
            }.padding().background(Color.black)
                .navigationTitle(existing ? "Edit note" : "New note").navigationBarTitleDisplayMode(.inline)
                .interactiveDismissDisabled()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") {
                        note.updatedAt = .now
                        if model.editLife({ state in
                            if let index = state.notes.firstIndex(where: { $0.id == note.id }) { state.notes[index] = note }
                            else { state.notes.append(note) }
                        }) { dismiss() }
                    }.disabled(note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }
                .confirmationDialog("Delete this note?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                    Button("Delete note", role: .destructive) { if model.editLife({ $0.notes.removeAll { $0.id == note.id } }) { dismiss() } }
                }
        }
    }
}
