module Notes
  class Destroy
    def self.call(note_id:)
      Note.find(note_id).destroy!
    end
  end
end