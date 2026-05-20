import Foundation

public enum AppLanguage: String, CaseIterable, Codable, Sendable {
    case english = "en"
    case russian = "ru"
    case spanish = "es"
    case turkish = "tr"
    case german = "de"

    public var displayName: String {
        switch self {
        case .english: "English"
        case .russian: "Русский"
        case .spanish: "Español"
        case .turkish: "Türkçe"
        case .german: "Deutsch"
        }
    }

    public var openAIParameter: String {
        rawValue
    }

    public static var defaultLanguage: AppLanguage {
        let preferred = Locale.preferredLanguages.first?.split(separator: "-").first.map(String.init)
        return AppLanguage(rawValue: preferred ?? "") ?? .english
    }
}

public enum AppText {
    public static func languageLabel(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Language"
        case .russian: "Язык"
        case .spanish: "Idioma"
        case .turkish: "Dil"
        case .german: "Sprache"
        }
    }

    public static func languageHint(_ language: AppLanguage) -> String {
        switch language {
        case .english: "used for the interface and transcription language hint"
        case .russian: "используется для интерфейса и подсказки языка транскрибации"
        case .spanish: "se usa para la interfaz y la pista de idioma de transcripción"
        case .turkish: "arayüz ve transkripsiyon dili ipucu için kullanılır"
        case .german: "wird für Oberfläche und Transkriptionssprache verwendet"
        }
    }

    public static func apiKeyLabel(_ language: AppLanguage) -> String {
        switch language {
        case .english: "OpenAI API Key"
        case .russian: "OpenAI API Key"
        case .spanish: "Clave API de OpenAI"
        case .turkish: "OpenAI API anahtarı"
        case .german: "OpenAI API-Schlüssel"
        }
    }

    public static func save(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Save"
        case .russian: "Сохранить"
        case .spanish: "Guardar"
        case .turkish: "Kaydet"
        case .german: "Speichern"
        }
    }

    public static func transcriptionModel(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Transcription model"
        case .russian: "Модель транскрипции"
        case .spanish: "Modelo de transcripción"
        case .turkish: "Transkripsiyon modeli"
        case .german: "Transkriptionsmodell"
        }
    }

    public static func refreshModels(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Refresh models"
        case .russian: "Обновить модели"
        case .spanish: "Actualizar modelos"
        case .turkish: "Modelleri yenile"
        case .german: "Modelle aktualisieren"
        }
    }

    public static func modelHint(_ language: AppLanguage) -> String {
        switch language {
        case .english: "loaded online through the OpenAI Models API"
        case .russian: "список загружается онлайн через OpenAI Models API"
        case .spanish: "se carga en línea mediante la API de modelos de OpenAI"
        case .turkish: "OpenAI Models API üzerinden çevrimiçi yüklenir"
        case .german: "wird online über die OpenAI Models API geladen"
        }
    }

    public static func hotkeyLabel(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Dictation hotkey"
        case .russian: "Клавиша диктовки"
        case .spanish: "Tecla de dictado"
        case .turkish: "Dikte kısayolu"
        case .german: "Diktat-Taste"
        }
    }

    public static func reset(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Reset"
        case .russian: "Сбросить"
        case .spanish: "Restablecer"
        case .turkish: "Sıfırla"
        case .german: "Zurücksetzen"
        }
    }

    public static func permissions(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Permissions"
        case .russian: "Разрешения"
        case .spanish: "Permisos"
        case .turkish: "İzinler"
        case .german: "Berechtigungen"
        }
    }

    public static func logs(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Logs"
        case .russian: "Логи"
        case .spanish: "Registros"
        case .turkish: "Günlükler"
        case .german: "Protokolle"
        }
    }

    public static func launchAtLogin(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Launch at login"
        case .russian: "Запускать при входе"
        case .spanish: "Abrir al iniciar sesión"
        case .turkish: "Oturum açınca başlat"
        case .german: "Beim Anmelden starten"
        }
    }

    public static func quit(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Quit"
        case .russian: "Выход"
        case .spanish: "Salir"
        case .turkish: "Çık"
        case .german: "Beenden"
        }
    }

    public static func quitApp(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Quit Dictation"
        case .russian: "Выйти из Dictation"
        case .spanish: "Salir de Dictation"
        case .turkish: "Dictation'dan çık"
        case .german: "Dictation beenden"
        }
    }

    public static func editMenu(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Edit"
        case .russian: "Правка"
        case .spanish: "Edición"
        case .turkish: "Düzenle"
        case .german: "Bearbeiten"
        }
    }

    public static func cut(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Cut"
        case .russian: "Вырезать"
        case .spanish: "Cortar"
        case .turkish: "Kes"
        case .german: "Ausschneiden"
        }
    }

    public static func copy(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Copy"
        case .russian: "Копировать"
        case .spanish: "Copiar"
        case .turkish: "Kopyala"
        case .german: "Kopieren"
        }
    }

    public static func paste(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Paste"
        case .russian: "Вставить"
        case .spanish: "Pegar"
        case .turkish: "Yapıştır"
        case .german: "Einfügen"
        }
    }

    public static func selectAll(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Select All"
        case .russian: "Выбрать все"
        case .spanish: "Seleccionar todo"
        case .turkish: "Tümünü seç"
        case .german: "Alles auswählen"
        }
    }

    public static func footer(version: String, developerEmail: String, language: AppLanguage) -> String {
        switch language {
        case .english: "Version: \(version)\nCreated by: \(developerEmail)"
        case .russian: "Версия: \(version)\nСоздано: \(developerEmail)"
        case .spanish: "Versión: \(version)\nCreado por: \(developerEmail)"
        case .turkish: "Sürüm: \(version)\nOluşturan: \(developerEmail)"
        case .german: "Version: \(version)\nErstellt von: \(developerEmail)"
        }
    }

    public static func hotkeyCapturePlaceholder(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Press a key..."
        case .russian: "Нажмите клавишу..."
        case .spanish: "Pulsa una tecla..."
        case .turkish: "Bir tuşa basın..."
        case .german: "Taste drücken..."
        }
    }

    public static func hotkeyCaptureHelp(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Press Fn, Command, Option, Control, or F13-F20."
        case .russian: "Нажмите Fn, Command, Option, Control или F13-F20."
        case .spanish: "Pulsa Fn, Command, Option, Control o F13-F20."
        case .turkish: "Fn, Command, Option, Control veya F13-F20 tuşuna basın."
        case .german: "Fn, Command, Option, Control oder F13-F20 drücken."
        }
    }

    public static func invalidHotkeyKeyDown(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Choose Fn, Command, Option, Control, or F13-F20."
        case .russian: "Выберите Fn, Command, Option, Control или F13-F20."
        case .spanish: "Elige Fn, Command, Option, Control o F13-F20."
        case .turkish: "Fn, Command, Option, Control veya F13-F20 seçin."
        case .german: "Fn, Command, Option, Control oder F13-F20 wählen."
        }
    }

    public static func invalidHotkeyHold(_ language: AppLanguage) -> String {
        switch language {
        case .english: "This key is not suitable for hold-to-dictate."
        case .russian: "Эта клавиша не подходит для удержания."
        case .spanish: "Esta tecla no sirve para mantener y dictar."
        case .turkish: "Bu tuş basılı tutarak dikte için uygun değil."
        case .german: "Diese Taste ist nicht für Halten-zum-Diktieren geeignet."
        }
    }

    public static func modelBadge(_ badge: String, language: AppLanguage) -> String {
        switch badge {
        case "fast": return modelBadgeFast(language)
        case "accurate": return modelBadgeAccurate(language)
        case "speakers": return modelBadgeSpeakers(language)
        default: return "classic"
        }
    }

    public static func modelBadgeFast(_ language: AppLanguage) -> String {
        switch language {
        case .english: "fast"
        case .russian: "быстро"
        case .spanish: "rápido"
        case .turkish: "hızlı"
        case .german: "schnell"
        }
    }

    public static func modelBadgeAccurate(_ language: AppLanguage) -> String {
        switch language {
        case .english: "accurate"
        case .russian: "точнее"
        case .spanish: "preciso"
        case .turkish: "doğru"
        case .german: "genau"
        }
    }

    public static func modelBadgeSpeakers(_ language: AppLanguage) -> String {
        switch language {
        case .english: "speakers"
        case .russian: "спикеры"
        case .spanish: "hablantes"
        case .turkish: "konuşmacılar"
        case .german: "Sprecher"
        }
    }

    public static func validationUnchecked(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Not checked"
        case .russian: "Не проверено"
        case .spanish: "Sin comprobar"
        case .turkish: "Kontrol edilmedi"
        case .german: "Nicht geprüft"
        }
    }

    public static func validationAccepted(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Token accepted"
        case .russian: "Токен принят"
        case .spanish: "Token aceptado"
        case .turkish: "Token kabul edildi"
        case .german: "Token akzeptiert"
        }
    }

    public static func validationFailed(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Token error"
        case .russian: "Ошибка токена"
        case .spanish: "Error de token"
        case .turkish: "Token hatası"
        case .german: "Tokenfehler"
        }
    }

    public static func ready(hotkey: String, language: AppLanguage) -> String {
        switch language {
        case .english: "Ready. Hold \(hotkey) to dictate."
        case .russian: "Готово. Удерживайте \(hotkey) для диктовки."
        case .spanish: "Listo. Mantén \(hotkey) para dictar."
        case .turkish: "Hazır. Dikte için \(hotkey) tuşunu basılı tutun."
        case .german: "Bereit. \(hotkey) zum Diktieren halten."
        }
    }

    public static func permissionsOk(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Permissions granted."
        case .russian: "Разрешения выданы."
        case .spanish: "Permisos concedidos."
        case .turkish: "İzinler verildi."
        case .german: "Berechtigungen erteilt."
        }
    }

    public static func microphoneOkAccessibilityNeeded(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Microphone allowed. Confirm Accessibility."
        case .russian: "Микрофон разрешен. Подтвердите Accessibility."
        case .spanish: "Micrófono permitido. Confirma Accessibility."
        case .turkish: "Mikrofona izin verildi. Accessibility iznini onaylayın."
        case .german: "Mikrofon erlaubt. Accessibility bestätigen."
        }
    }

    public static func permissionsNeeded(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Microphone and Accessibility access are required."
        case .russian: "Нужен доступ к микрофону и Accessibility."
        case .spanish: "Se necesitan permisos de micrófono y Accessibility."
        case .turkish: "Mikrofon ve Accessibility izni gerekli."
        case .german: "Mikrofon- und Accessibility-Zugriff sind erforderlich."
        }
    }

    public static func saveTokenFirst(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Save an OpenAI API key first."
        case .russian: "Сначала сохраните OpenAI API key."
        case .spanish: "Primero guarda una clave API de OpenAI."
        case .turkish: "Önce OpenAI API anahtarını kaydedin."
        case .german: "Zuerst einen OpenAI API-Schlüssel speichern."
        }
    }

    public static func recording(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Recording..."
        case .russian: "Запись..."
        case .spanish: "Grabando..."
        case .turkish: "Kaydediliyor..."
        case .german: "Aufnahme..."
        }
    }

    public static func recordingTooShort(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Recording was too short and was deleted."
        case .russian: "Слишком короткая запись удалена."
        case .spanish: "La grabación era demasiado corta y se eliminó."
        case .turkish: "Kayıt çok kısaydı ve silindi."
        case .german: "Die Aufnahme war zu kurz und wurde gelöscht."
        }
    }

    public static func transcribing(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Recording finished. Transcribing..."
        case .russian: "Запись завершена. Распознаю..."
        case .spanish: "Grabación finalizada. Transcribiendo..."
        case .turkish: "Kayıt bitti. Yazıya dökülüyor..."
        case .german: "Aufnahme beendet. Transkribiere..."
        }
    }

    public static func apiKeyMissing(_ language: AppLanguage) -> String {
        switch language {
        case .english: "OpenAI API key was not found."
        case .russian: "OpenAI API key не найден."
        case .spanish: "No se encontró la clave API de OpenAI."
        case .turkish: "OpenAI API anahtarı bulunamadı."
        case .german: "OpenAI API-Schlüssel nicht gefunden."
        }
    }

    public static func emptyTranscription(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Empty transcription."
        case .russian: "Пустая транскрибация."
        case .spanish: "Transcripción vacía."
        case .turkish: "Boş transkripsiyon."
        case .german: "Leere Transkription."
        }
    }

    public static func inserted(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Inserted."
        case .russian: "Вставлено."
        case .spanish: "Insertado."
        case .turkish: "Eklendi."
        case .german: "Eingefügt."
        }
    }

    public static func recognizedButNotInserted(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Text recognized but not inserted. Recording deleted."
        case .russian: "Текст распознан, но не вставлен. Запись удалена."
        case .spanish: "Texto reconocido, pero no insertado. Grabación eliminada."
        case .turkish: "Metin tanındı ama eklenmedi. Kayıt silindi."
        case .german: "Text erkannt, aber nicht eingefügt. Aufnahme gelöscht."
        }
    }

    public static func corruptedRecordingDeleted(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Corrupted recording deleted. Record again."
        case .russian: "Поврежденная запись удалена. Запишите заново."
        case .spanish: "Grabación dañada eliminada. Graba de nuevo."
        case .turkish: "Bozuk kayıt silindi. Yeniden kaydedin."
        case .german: "Beschädigte Aufnahme gelöscht. Bitte erneut aufnehmen."
        }
    }

    public static func genericErrorDeleted(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Error. Recording deleted, please try again."
        case .russian: "Ошибка. Запись удалена, попробуйте еще раз."
        case .spanish: "Error. Grabación eliminada, inténtalo de nuevo."
        case .turkish: "Hata. Kayıt silindi, tekrar deneyin."
        case .german: "Fehler. Aufnahme gelöscht, bitte erneut versuchen."
        }
    }

    public static func accessibilitySettings(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Allow Accessibility: Privacy & Security -> Accessibility -> Dictation."
        case .russian: "Разрешите Accessibility: Privacy & Security -> Accessibility -> Dictation."
        case .spanish: "Permite Accessibility: Privacy & Security -> Accessibility -> Dictation."
        case .turkish: "Accessibility izni verin: Privacy & Security -> Accessibility -> Dictation."
        case .german: "Accessibility erlauben: Privacy & Security -> Accessibility -> Dictation."
        }
    }

    public static func checkingToken(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Checking token..."
        case .russian: "Проверяю токен..."
        case .spanish: "Comprobando token..."
        case .turkish: "Token kontrol ediliyor..."
        case .german: "Token wird geprüft..."
        }
    }

    public static func tokenCleared(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Token cleared."
        case .russian: "Токен очищен."
        case .spanish: "Token borrado."
        case .turkish: "Token temizlendi."
        case .german: "Token gelöscht."
        }
    }

    public static func tokenAcceptedModelsLoaded(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Token accepted. Models loaded online."
        case .russian: "Токен принят. Модели загружены онлайн."
        case .spanish: "Token aceptado. Modelos cargados en línea."
        case .turkish: "Token kabul edildi. Modeller çevrimiçi yüklendi."
        case .german: "Token akzeptiert. Modelle online geladen."
        }
    }

    public static func tokenValidationFailed(_ error: String, language: AppLanguage) -> String {
        switch language {
        case .english: "Token check failed: \(error)"
        case .russian: "Токен не прошел проверку: \(error)"
        case .spanish: "La comprobación del token falló: \(error)"
        case .turkish: "Token kontrolü başarısız: \(error)"
        case .german: "Tokenprüfung fehlgeschlagen: \(error)"
        }
    }

    public static func hotkeyChanged(_ hotkey: String, language: AppLanguage) -> String {
        switch language {
        case .english: "Dictation key: \(hotkey)."
        case .russian: "Клавиша диктовки: \(hotkey)."
        case .spanish: "Tecla de dictado: \(hotkey)."
        case .turkish: "Dikte tuşu: \(hotkey)."
        case .german: "Diktat-Taste: \(hotkey)."
        }
    }

    public static func loadingModels(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Loading models online..."
        case .russian: "Загружаю модели онлайн..."
        case .spanish: "Cargando modelos en línea..."
        case .turkish: "Modeller çevrimiçi yükleniyor..."
        case .german: "Modelle werden online geladen..."
        }
    }

    public static func modelsUpdated(_ language: AppLanguage) -> String {
        switch language {
        case .english: "Models updated from OpenAI."
        case .russian: "Модели обновлены из OpenAI."
        case .spanish: "Modelos actualizados desde OpenAI."
        case .turkish: "Modeller OpenAI'dan güncellendi."
        case .german: "Modelle von OpenAI aktualisiert."
        }
    }

    public static func modelsLoadFailed(_ error: String, language: AppLanguage) -> String {
        switch language {
        case .english: "Could not load models: \(error)"
        case .russian: "Не удалось загрузить модели: \(error)"
        case .spanish: "No se pudieron cargar los modelos: \(error)"
        case .turkish: "Modeller yüklenemedi: \(error)"
        case .german: "Modelle konnten nicht geladen werden: \(error)"
        }
    }

    public static func launchAtLoginChanged(_ enabled: Bool, language: AppLanguage) -> String {
        switch (language, enabled) {
        case (.english, true): "Launch at login enabled."
        case (.english, false): "Launch at login disabled."
        case (.russian, true): "Автозапуск включен."
        case (.russian, false): "Автозапуск выключен."
        case (.spanish, true): "Inicio automático activado."
        case (.spanish, false): "Inicio automático desactivado."
        case (.turkish, true): "Oturum açınca başlatma açıldı."
        case (.turkish, false): "Oturum açınca başlatma kapatıldı."
        case (.german, true): "Beim Anmelden starten aktiviert."
        case (.german, false): "Beim Anmelden starten deaktiviert."
        }
    }

    public static func launchAtLoginFailed(_ error: String, language: AppLanguage) -> String {
        switch language {
        case .english: "Could not change launch at login: \(error)"
        case .russian: "Не удалось изменить автозапуск: \(error)"
        case .spanish: "No se pudo cambiar el inicio automático: \(error)"
        case .turkish: "Oturum başlangıcı değiştirilemedi: \(error)"
        case .german: "Start beim Anmelden konnte nicht geändert werden: \(error)"
        }
    }

    public static func recordingStartFailed(_ error: String, language: AppLanguage) -> String {
        switch language {
        case .english: "Could not start recording: \(error)"
        case .russian: "Не удалось начать запись: \(error)"
        case .spanish: "No se pudo iniciar la grabación: \(error)"
        case .turkish: "Kayıt başlatılamadı: \(error)"
        case .german: "Aufnahme konnte nicht gestartet werden: \(error)"
        }
    }

    public static func recordingFinishFailed(_ error: String, language: AppLanguage) -> String {
        switch language {
        case .english: "Could not save recording: \(error)"
        case .russian: "Не удалось сохранить запись: \(error)"
        case .spanish: "No se pudo guardar la grabación: \(error)"
        case .turkish: "Kayıt kaydedilemedi: \(error)"
        case .german: "Aufnahme konnte nicht gespeichert werden: \(error)"
        }
    }
}
