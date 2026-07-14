# Loads the Solid Queue schema (db/queue_schema.rb) into the primary database.
# In development/test we run Solid Queue on the single primary DB rather than a
# dedicated queue database, so the dedicated `worker` container can process jobs.
class CreateSolidQueueTables < ActiveRecord::Migration[8.0]
  def up
    instance_eval(File.read(Rails.root.join("db", "queue_schema.rb")))
  end

  def down
    tables = %w[
      solid_queue_blocked_executions solid_queue_claimed_executions
      solid_queue_failed_executions solid_queue_ready_executions
      solid_queue_recurring_executions solid_queue_scheduled_executions
      solid_queue_jobs solid_queue_pauses solid_queue_processes
      solid_queue_recurring_tasks solid_queue_semaphores
    ]
    tables.each { |t| drop_table t, if_exists: true }
  end
end
