using BuildYourOwnCopilot.Common.Models.Chat;
using BuildYourOwnCopilot.Service.Models.Chat;

namespace BuildYourOwnCopilot.Service.Interfaces
{
    public interface ISemanticCacheService
    {
        Task Initialize();
        Task Reset();
        void SetMinRelevanceOverride(double minRelevance);

        Task<SemanticCacheItem> GetCacheItem(string userPrompt, List<Message> messageHistory);
        Task SetCacheItem(SemanticCacheItem cacheItem);
    }
}
