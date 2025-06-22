/**
 * Interface for acknowledgement processing commands
 * Enables polymorphic command execution in the Command pattern
 */
public interface IAcknowledgementCommand {
  /**
   * Execute the command
   * Implementation varies by command type - some modify shared state, others return specific outputs
   */
  void execute();
}
