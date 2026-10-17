/** Sample: the only line a HIVE-S trigger needs. Copy it for each object you add handlers to. */
trigger AccountTrigger on Account (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    HIVES_Trigger.run();
}
