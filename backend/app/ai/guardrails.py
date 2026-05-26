import re
from difflib import SequenceMatcher
from typing import List, Tuple

MIN_MESSAGE_LENGTH_FOR_CALC = 3
MAX_CALCULATION_MESSAGE_LENGTH = 30


def normalize_text(text: str) -> str:
    if not text:
        return ""

    text = text.lower().strip()
    text = text.replace("ё", "е")
    text = re.sub(r"[^а-яa-z0-9\s\+\-\*/\^\=\?]", " ", text)
    text = re.sub(r"\s+", " ", text)

    return text.strip()


def get_words(text: str) -> list[str]:
    normalized = normalize_text(text)
    return normalized.split()


def similarity(a: str, b: str) -> float:
    return SequenceMatcher(None, a, b).ratio()


def has_close_word(
    words: list[str],
    targets: list[str],
    threshold: float = 0.78,
) -> bool:
    for word in words:
        for target in targets:
            if similarity(word, target) >= threshold:
                return True

    return False


def contains_any_phrase(text: str, phrases: list[str]) -> bool:
    normalized = normalize_text(text)

    return any(
        normalize_text(phrase) in normalized
        for phrase in phrases
    )


def is_crisis_message(message: str) -> bool:
    if not message or not message.strip():
        return False

    normalized_message = normalize_text(message)
    words = get_words(message)

    crisis_phrases = [
        "хочу умереть", "не хочу жить", "не хочу больше жить", "жить не хочу",
        "больше не хочу жить", "больше не могу жить", "нет смысла жить",
        "мне незачем жить", "лучше бы меня не было", "хочу исчезнуть навсегда",
        "покончить с собой", "покончу с собой", "совершить самоубийство",
        "убить себя", "убью себя", "я себя убью", "наложить на себя руки",
        "причинить себе вред", "навредить себе", "хочу навредить себе",
        "режу себя", "резать себя", "порезать себя", "порежу себя",
        "хочу порезать себя", "сделать себе больно", "хочу сделать себе больно",
        "я в опасности", "мне угрожают", "меня хотят убить",
        "мне сейчас опасно", "я боюсь за свою жизнь",
        "моя жизнь в опасности", "у меня есть план",
        "я уже решила как", "я уже решил как", "я знаю как умереть",
        "я приготовила таблетки", "я приготовил таблетки",
        "наглотаться таблеток", "спрыгнуть", "повеситься",
    ]

    if contains_any_phrase(normalized_message, crisis_phrases):
        return True

    crisis_roots = [
        "суицид", "суицидальн", "суцид", "суцидальн",
        "самоубийств", "самоубийство", "умереть", "умерет",
        "убить", "убью", "навредить", "вред", "порезать",
        "порежу", "режу", "таблеток", "повеситься", "спрыгнуть",
    ]

    for word in words:
        for root in crisis_roots:
            if root in word:
                return True

    high_risk_words = [
        "суицид", "суицидальные", "самоубийство",
        "умереть", "убью", "навредить",
        "порезать", "повеситься", "спрыгнуть",
    ]

    if has_close_word(words, high_risk_words, threshold=0.76):
        return True

    return False


def is_pure_calculation(message: str) -> bool:
    if not message:
        return False

    if len(message) > MAX_CALCULATION_MESSAGE_LENGTH:
        return False

    normalized = normalize_text(message)

    emotional_markers = [
        "чувствую", "боюсь", "тревога", "грустно",
        "радостно", "обидно", "страшно", "переживаю",
        "волнуюсь", "ненавижу", "люблю", "ненависть",
        "стыд", "вина",
    ]

    if any(marker in normalized for marker in emotional_markers):
        return False

    cbt_scale_markers = [
        "тревога", "настроение", "страх", "грусть",
        "злость", "эмоция", "эмоции", "чувство",
        "чувства", "стресс", "паника", "оцениваю",
        "уровень",
    ]

    if any(marker in normalized for marker in cbt_scale_markers):
        return False

    calc_patterns = [
        r"^\s*\d+\s*[\+\-\*/\^]\s*\d+\s*$",
        r"^\s*\d+\s*[\+\-\*/\^]\s*\d+\s*[\+\-\*/\^]\s*\d+\s*$",
        r"^\s*\d+\s*[\+\-\*/\^]\s*\d+\s*=\s*$",
        r"^\s*сколько\s+будет\s+\d+\s*[\+\-\*/\^]\s*\d+\s*\??\s*$",
        r"^\s*посчитай\s+\d+\s*[\+\-\*/\^]\s*\d+\s*\??\s*$",
        r"^\s*\d+\s*[\+\-\*/\^]\s*\d+\s*\?\s*$",
    ]

    return any(
        re.match(pattern, normalized, re.IGNORECASE)
        for pattern in calc_patterns
    )


def extract_emotional_context(message: str) -> Tuple[bool, List[str]]:
    normalized = normalize_text(message)

    emotional_keywords = {
        "чувствую", "переживаю", "тревога", "тревожно", "страшно", "страх",
        "стыдно", "стыд", "вина", "виноват", "виновата", "грусть",
        "грустно", "злость", "злюсь", "зол", "зла", "обидно", "обида",
        "больно", "боль", "одиноко", "одиночество", "радость",
        "радостно", "счастье", "счастлив", "поссорилась",
        "поссорился", "ссора", "расстроилась", "расстроился",
        "плачу", "паника", "паникую", "нервничаю", "волнуюсь",
        "боюсь", "устал", "устала", "усталость", "бессилие",
        "разочарование", "мысль", "мысли", "думаю", "думать",
        "кажется", "понимаю", "осознаю", "анализирую",
        "я", "мне", "меня", "мой", "моя", "моё", "мои",
        "мама", "папа", "родители", "подруга", "друг",
        "отношения", "парень", "девушка", "муж", "жена",
        "семья", "коллега", "начальник", "работа", "учеба",
        "экзамен", "экзамены", "дедлайн", "проблема",
        "трудность", "ситуация", "случилось", "произошло",
        "вчера", "сегодня",
    }

    found_keywords = [
        keyword
        for keyword in emotional_keywords
        if keyword in normalized
    ]

    return len(found_keywords) > 0, found_keywords


def contains_off_topic_domains(
    message: str,
    has_emotional_context: bool,
) -> bool:

    normalized = normalize_text(message)
    words = get_words(message)

    hard_off_topic_patterns = [
        r"расстояни[ея]\s+от\s+земл[ия]\s+до\s+(луны|солнца|марса)",
        r"расстояни[ея]\s+до\s+(луны|солнца|марса|венеры)",
        r"сколько\s+(километров|световых\s+лет)\s+до\s+(луны|солнца|марса)",
        r"как\s+далеко\s+(луна|солнце|марс)",
        r"диаметр\s+(земли|луны|солнца|марса)",
        r"масса\s+(земли|луны|солнца)",
        r"температура\s+(на|в)\s+(луне|солнце|марсе|космосе)",
        r"(напиши|сделай|исправь|объясни)\s+(код|программу|функцию|класс|алгоритм)",
        r"(python|javascript|java|react|html|css|sql)\s+(код|функция|класс)",
        r"(дай|напиши|подскажи|нужен)\s+(рецепт|ингредиенты)",
        r"как\s+(приготовить|сделать|испечь)\s+(суп|борщ|торт|пирог|блины)",
        r"(расскажи|придумай|напиши)\s+(анекдот|шутку|стих|песню|мем)",
        r"рассмеши\s+(меня|плиз)",
        r"(сгенерируй|пришли|покажи)\s+(мем|картинку|фото)",
        r"(кто|что)\s+(такой|такая|такое)\s+(президент|премьер|актер|певец|ученый)",
        r"биография\s+(актера|певца|политика|ученого)",
        r"(расскажи|объясни)\s+(про|о)\s+(космос|астрономи|физик|хими|биологи|географи|истори)",
    ]

    for pattern in hard_off_topic_patterns:
        if re.search(pattern, normalized):
            return True

    strong_off_topic_phrases = [
        "напиши код", "сделай код", "помоги с кодом", "исправь код",
        "объясни код", "создай сайт", "напиши программу",
        "реши ошибку в коде", "реши задачу по математике",
        "реши пример", "найди производную", "найди интеграл",
        "реши уравнение", "вычисли", "дай рецепт",
        "как приготовить", "что происходит в новостях",
        "последние новости", "расскажи новости",
        "расскажи анекдот", "раскажи анекдот",
        "расскажи аникдот", "раскажи аникдот",
        "напиши стих", "сочини стих", "напиши песню",
        "кто такой", "кто такая", "биография",
    ]

    if contains_any_phrase(normalized, strong_off_topic_phrases):
        return True

    request_words = [
        "напиши", "сделай", "объясни", "расскажи",
        "раскажи", "покажи", "создай", "придумай",
        "реши", "вычисли", "посчитай", "дай",
    ]

    off_topic_words = [
        "код", "python", "java", "javascript", "react",
        "flutter", "fastapi", "sql", "html", "css",
        "математика", "алгебра", "геометрия",
        "интеграл", "производная", "уравнение",
        "луна", "солнце", "марс", "космос",
        "астрономия", "физика", "химия",
        "рецепт", "борщ", "суп", "торт",
        "политика", "новости", "анекдот",
        "аникдот", "стих", "песня", "мем",
        "знаменитость", "актер", "актриса",
        "певец", "певица",
    ]

    has_request_word = has_close_word(
        words,
        request_words,
        threshold=0.78,
    )

    has_off_topic_word = has_close_word(
        words,
        off_topic_words,
        threshold=0.78,
    )

    if has_request_word and has_off_topic_word:
        return True

    if not has_emotional_context:

        weak_off_topic_domains = [
            "код", "программирование", "алгоритм",
            "python", "java", "javascript", "react",
            "sql", "html", "css", "математика",
            "алгебра", "геометрия", "интеграл",
            "производная", "уравнение", "луна",
            "солнце", "марс", "венера", "космос",
            "планета", "астрономия", "гравитация",
            "галактика", "физика", "химия",
            "биология", "география", "история",
            "политика", "новости", "анекдот",
            "аникдот", "мем", "шутка", "рецепт",
            "борщ", "торт", "омлет", "актер",
            "актриса", "биография",
        ]

        return any(domain in normalized for domain in weak_off_topic_domains)

    return False


def is_off_topic(
    message: str,
    session_context: dict = None,
) -> bool:

    if not message or not message.strip():
        return False

    if is_crisis_message(message):
        return False

    normalized = normalize_text(message)

    if is_pure_calculation(message):
        return True

    has_emotional_context, emotions_found = extract_emotional_context(message)

    if has_emotional_context:
        return False

    if contains_off_topic_domains(
        message,
        has_emotional_context,
    ):
        return True

    request_patterns = [
        r"^(расскажи|объясни|покажи|научи|вычисли|посчитай)\s",
        r"^(как|почему|что|сколько|какой|какая|какое|кто)\s",
        r"^(напиши|сделай|создай|придумай|сгенерируй)\s",
        r"^(помоги|подскажи)\s+(с|по|как|почему|что)",
    ]

    personal_markers = [
        "я", "меня", "мне", "мной", "моя", "моё", "мои",
        "чувствую", "переживаю", "тревога", "боюсь",
        "страшно", "проблема", "ситуация",
        "случилось", "произошло",
    ]

    has_personal_context = any(
        marker in normalized
        for marker in personal_markers
    )

    for pattern in request_patterns:
        if re.search(pattern, normalized):
            if not has_personal_context:
                return True

    return False


def get_moderation_result(message: str) -> dict:
    crisis = is_crisis_message(message)
    calculation = is_pure_calculation(message)
    has_emotions, emotions_found = extract_emotional_context(message)
    off_topic = is_off_topic(message)

    return {
        "original_message": message,
        "is_crisis": crisis,
        "is_pure_calculation": calculation,
        "has_emotional_context": has_emotions,
        "emotions_found": emotions_found[:5],
        "is_off_topic": off_topic,
        "should_block": off_topic and not crisis,
    }