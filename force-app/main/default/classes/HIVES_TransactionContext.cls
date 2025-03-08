/**
 * @description Transaction context to maintain state across triggers
 * Provides a unified way to share data between triggers in the same transaction.
 * 
 * @author HIVE-S Framework
 * @date 2025-03-08
 */
public class HIVES_TransactionContext {
    private String transactionId;
    private Map<String, Object> contextData;
    
    /**
     * @description Constructor initializes a new transaction context
     */
    public HIVES_TransactionContext() {
        this.transactionId = generateTransactionId();
        this.contextData = new Map<String, Object>();
    }
    
    /**
     * @description Generate a unique ID for this transaction
     * @return String The transaction ID
     */
    private String generateTransactionId() {
        return UserInfo.getUserId() + '-' + 
               Datetime.now().getTime() + '-' + 
               String.valueOf(Math.random()).substring(2, 8);
    }
    
    /**
     * @description Get the transaction ID
     * @return String The transaction ID
     */
    public String getTransactionId() {
        return transactionId;
    }
    
    /**
     * @description Store data in the transaction context
     * @param key The key to store the data under
     * @param value The value to store
     */
    public void put(String key, Object value) {
        contextData.put(key, value);
    }
    
    /**
     * @description Retrieve data from the transaction context
     * @param key The key to retrieve
     * @return Object The stored value
     */
    public Object get(String key) {
        return contextData.get(key);
    }
    
    /**
     * @description Check if the context contains a key
     * @param key The key to check for
     * @return Boolean Whether the key exists
     */
    public Boolean containsKey(String key) {
        return contextData.containsKey(key);
    }
    
    /**
     * @description Remove a key from the context
     * @param key The key to remove
     */
    public void remove(String key) {
        contextData.remove(key);
    }
    
    /**
     * @description Get all keys in the context
     * @return Set<String> Set of all keys
     */
    public Set<String> getKeys() {
        return contextData.keySet();
    }
    
    /**
     * @description Check if context has any data
     * @return Boolean True if context has data
     */
    public Boolean isEmpty() {
        return contextData.isEmpty();
    }
    
    /**
     * @description Get the size of the context
     * @return Integer Number of items in context
     */
    public Integer size() {
        return contextData.size();
    }
}
