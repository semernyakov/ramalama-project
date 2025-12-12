.PHONY: help build rebuild test clean info list shell version backup setup-dirs

# Цвета для вывода
BLUE := \033[0;34m
GREEN := \033[0;32m
RED := \033[0;31m
YELLOW := \033[1;33m
NC := \033[0m

help:
	@echo "$(BLUE)RamaLama Docker - Команды управления$(NC)"
	@echo ""
	@echo "$(GREEN)Основные команды:$(NC)"
	@echo "  make setup-dirs - Проверить и создать директории"
	@echo "  make build      - Собрать Docker образ"
	@echo "  make rebuild    - Пересобрать образ с нуля"
	@echo "  make test       - Запустить тесты"
	@echo "  make clean      - Очистить контейнеры и образы"
	@echo ""
	@echo "$(GREEN)Информация:$(NC)"
	@echo "  make info       - Показать информацию о системе"
	@echo "  make list       - Список локальных моделей"
	@echo "  make version    - Показать версию ramalama"
	@echo ""
	@echo "$(GREEN)Разработка:$(NC)"
	@echo "  make shell      - Открыть bash в контейнере"
	@echo ""
	@echo "$(GREEN)Использование моделей:$(NC)"
	@echo "  make pull MODEL=llama3.2:1b"
	@echo "  make run MODEL=llama3.2:1b"
	@echo "  make serve MODEL=llama3.2:1b PORT=8080"
	@echo ""
	@echo "$(GREEN)Бэкапы и мониторинг:$(NC)"
	@echo "  make backup     - Создать бэкап моделей"
	@echo "  make monitor    - Запустить мониторинг системы"
	@echo ""
	@echo "$(GREEN)Установка:$(NC)"
	@echo "  make install    - Полная настройка проекта"

build:
	@echo "$(BLUE)Сборка Docker образа...$(NC)"
	@./ramalama.sh build

rebuild:
	@echo "$(BLUE)Пересборка Docker образа...$(NC)"
	@./ramalama.sh rebuild

test:
	@echo "$(BLUE)Запуск тестов...$(NC)"
	@./quick-test.sh

clean:
	@echo "$(BLUE)Очистка...$(NC)"
	@./ramalama.sh clean

# Новая команда для проверки и создания директорий
setup-dirs:
	@echo "$(BLUE)Проверка структуры директорий...$(NC)"
	@./setup-dirs.sh

info:
	@./ramalama.sh info

list:
	@./ramalama.sh list

version:
	@./ramalama.sh version

shell:
	@./ramalama.sh shell

# Команда для создания бэкапа
backup:
	@echo "$(BLUE)Создание бэкапа моделей...$(NC)"
	@./backup.sh create

# Команда для мониторинга
monitor:
	@echo "$(BLUE)Запуск мониторинга системы...$(NC)"
	@./monitor.sh

# Команды для работы с моделями
pull:
ifndef MODEL
	@echo "$(RED)Ошибка: укажите MODEL$(NC)"
	@echo "Пример: make pull MODEL=llama3.2:1b"
	@exit 1
endif
	@./ramalama.sh pull $(MODEL)

run:
ifndef MODEL
	@echo "$(RED)Ошибка: укажите MODEL$(NC)"
	@echo "Пример: make run MODEL=llama3.2:1b"
	@exit 1
endif
	@./ramalama.sh run $(MODEL)

serve:
ifndef MODEL
	@echo "$(RED)Ошибка: укажите MODEL$(NC)"
	@echo "Пример: make serve MODEL=llama3.2:1b PORT=8080"
	@exit 1
endif
ifdef PORT
	@./ramalama.sh serve $(MODEL) --port $(PORT)
else
	@./ramalama.sh serve $(MODEL)
endif

# Быстрая установка
install:
	@echo "$(BLUE)Настройка проекта...$(NC)"
	@chmod +x ramalama.sh quick-test.sh entrypoint.sh examples.sh monitor.sh backup.sh setup-dirs.sh
	@./setup-dirs.sh
	@echo "$(GREEN)✓ Проект настроен$(NC)"
	@make build
	@make test
