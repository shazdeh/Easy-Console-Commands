#include "logger.h"
#include <windows.h>
#include <string>
#include <unordered_set>

using namespace RE;

RE::BSFixedString GetClipboard(RE::StaticFunctionTag*) {
    if (!OpenClipboard(nullptr)) return {};

    HANDLE hData = GetClipboardData(CF_TEXT);
    if (hData == nullptr) {
        CloseClipboard();
        return {};
    }

    char* pszText = static_cast<char*>(GlobalLock(hData));
    if (pszText == nullptr) {
        CloseClipboard();
        return {};
    }

    std::string text(pszText);

    GlobalUnlock(hData);
    CloseClipboard();

    return text.c_str();
}

bool SetClipboard(RE::StaticFunctionTag*, RE::BSFixedString a_text) {
    if (!OpenClipboard(nullptr)) return false;

    if (!EmptyClipboard()) {
        CloseClipboard();
        return false;
    }

    const std::string& text = a_text.c_str();
    HGLOBAL hGlob = GlobalAlloc(GMEM_MOVEABLE, text.size() + 1);
    if (!hGlob) {
        CloseClipboard();
        return false;
    }

    memcpy(GlobalLock(hGlob), text.c_str(), text.size() + 1);
    GlobalUnlock(hGlob);

    if (!SetClipboardData(CF_TEXT, hGlob)) {
        GlobalFree(hGlob);
        CloseClipboard();
        return false;
    }

    CloseClipboard();
    return true;
}

RE::TESForm* LookupFormSmart(RE::StaticFunctionTag*, const RE::BSFixedString inputRaw) {
    if (!inputRaw.data() || inputRaw.empty()) return nullptr;

    std::string_view input = inputRaw.data();

    // trim
    while (!input.empty() && std::isspace(static_cast<unsigned char>(input.front()))) input.remove_prefix(1);
    while (!input.empty() && std::isspace(static_cast<unsigned char>(input.back()))) input.remove_suffix(1);

    if (input.empty()) return nullptr;

    bool hasPrefix = false;

    if (input.size() > 2 && input[0] == '0' && (input[1] == 'x' || input[1] == 'X')) {
        hasPrefix = true;
        input.remove_prefix(2);
    }

    bool hexCandidate = true;
    for (char c : input) {
        if (!std::isxdigit(static_cast<unsigned char>(c))) {
            hexCandidate = false;
            break;
        }
    }

    if (hexCandidate) {
        uint32_t formID = 0;
        auto begin = input.data();
        auto end = input.data() + input.size();

        std::from_chars(begin, end, formID, 16);

        return RE::TESForm::LookupByID(formID);
    }

    return RE::TESForm::LookupByEditorID(inputRaw);
}

RE::BSFixedString GetFormTypeString(RE::StaticFunctionTag*, RE::TESForm* form) {
    if (form) {
        return RE::FormTypeToString(form->GetFormType());
    }
    return "None";
}

RE::BSFixedString GetFormSource(RE::StaticFunctionTag*, RE::TESForm* form) {
    if (form) {
        // form->GetFile() returns the last plugin modifying form, not the source
        // so we look this up manually
        uint8_t modIndex = form->GetFormID() >> 24;
        uint32_t id = form->GetFormID();
        uint8_t top = id >> 24;

        auto* dh = RE::TESDataHandler::GetSingleton();
        if (top == 0xFE) {
            uint16_t lightIndex = (id >> 12) & 0xFFF;  // 0x000–0xFFF
            auto file = dh->LookupLoadedLightModByIndex(lightIndex);
            if (file) {
                return file->GetFilename();
            }
        } else {
            auto file = dh->LookupLoadedModByIndex(top);
            if (file) {
                return file->GetFilename();
            }
        }
    }

    return "";
}

std::vector<EnchantmentItem*> GetKnowableEnchantments(StaticFunctionTag*) {
    std::vector<EnchantmentItem*> enchants;
    std::unordered_set<EnchantmentItem*> enchantsSet;
    auto& all = TESDataHandler::GetSingleton()->GetFormArray<EnchantmentItem>();
    for (auto item : all) {
        if (item->data.baseEnchantment && enchantsSet.emplace(item->data.baseEnchantment).second) {
            enchants.push_back(item->data.baseEnchantment);
        }
    }

    return enchants;
}

void to_lower_ascii(std::string& s) {
    for (char& c : s) {
        if (c >= 'A' && c <= 'Z') {
            c = c - 'A' + 'a';
        }
    }
}

RE::BSFixedString GetGameLanguage(StaticFunctionTag*) {
    static std::string language;
    if (!language.empty()) return language;

    language = "english";
    auto ini = INISettingCollection::GetSingleton();
    if (ini) {
        auto setting = ini->GetSetting("sLanguage:General");
        if (setting && setting->GetType() == RE::Setting::Type::kString) {
            language = setting->GetString();
            to_lower_ascii(language);
        }
    }
    return language;
}

Actor* GetActorByName(StaticFunctionTag*, BSFixedString a_name) {
    std::string targetName = a_name.c_str();
    to_lower_ascii(targetName);
    size_t len = targetName.length();

    auto& allRefs = TESDataHandler::GetSingleton()->GetFormArray<TESNPC>();
    int counter = 0;
    for (auto* ref : allRefs) {
        std::string actorName = ref->fullName.c_str();
        if (actorName.length() != len) continue;
        to_lower_ascii(actorName);
        if (actorName == targetName) {
            return ref->GetUniqueActor();
        }
    }

    return nullptr;
}

bool PapyrusBinder(RE::BSScript::IVirtualMachine* vm) {
    vm->RegisterFunction("SetClipboard", "ECC_Utils", SetClipboard);
    vm->RegisterFunction("GetClipboard", "ECC_Utils", GetClipboard);
    vm->RegisterFunction("LookupFormSmart", "ECC_Utils", LookupFormSmart);
    vm->RegisterFunction("GetFormTypeString", "ECC_Utils", GetFormTypeString);
    vm->RegisterFunction("GetFormSource", "ECC_Utils", GetFormSource);
    vm->RegisterFunction("GetKnowableEnchantments", "ECC_Utils", GetKnowableEnchantments);
    vm->RegisterFunction("GetGameLanguage", "ECC_Utils", GetGameLanguage);
    vm->RegisterFunction("GetActorByName", "ECC_Utils", GetActorByName);

    return false;
}

SKSEPluginLoad(const SKSE::LoadInterface *skse) {
    SetupLog();
    SKSE::Init(skse);
    SKSE::GetPapyrusInterface()->Register(PapyrusBinder);
    return true;
}
