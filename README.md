# Установка
1. bundle install
2. Настройка конфигурации в config.yml  
2.1 Ввести данные соединения для Redis  
2.2 Ввести данные соединения для MongoDB
5. Запустить приложение bundle thin start

# Механика
Расчёт прибытия производится на основе подбора трёх наиболее близких к запрошенным координатам автомобилей (через возможности geoNear MongoDB). Их координаты просчитываются через формулу harvesine.

Кэширование базируется на сглаживании координат объекта до 3х знаков после запятой, т.о. мы получаем снижаем точность метки, но получаем окружность с погрешностью определения до 100м. Эта погрешность позволяет нам
* допустить передвижение автомобилей на относительно короткие расстояния без глобальных искажений времени прибытия
* исключает искажения GPS для стоящих на месте автомобилей
* позволяет нам "разбивать" карту города на сектора и сохранять для них  приблизительные данные прибытия в краткосрочной перспективе

Кэширование производится средствами Redis используя обычные ключи с указанным expire.
Методика кэширования позволяет динамически варьировать точность для различных объектов (потенциально для этого используется хэш accuracy_groups, который распределяет автомобили из выборки по удалению от искомого объекта) изменяя параметр прокидываемый в round в методе sharpen объекта BaseObject.
# Запросы
## Добавление автомобиля
#####Запрос  
`POST /car`  
___
#####Параметры  
(_Обязательное_) position [String]: "38.898, -77.037"  
(_Обязательное_) name [String]: "Mercedes"  
(_Опциональное_) active [Boolean]: true  
___
#####Ответ
```json
{car: { name: "Mercedes", active: true, position: [38.898, -77.037]}}
```
___
#####Ошибки
**HTTP Status: 404**
```json
{ error: "Name not provided" }```
В случае если имя не указано

**HTTP Status: 403**
```json
{ error: "Coordinates not provided or malformed" }```
В случае если координаты указаны неверно

**HTTP Status: 403**
```json
{ error: "Car with such name already exist!" }```
В случае если автомобиль с данным именем уже существует

## Обновление данных автомобиля
#####Запрос  
`PUT /car`  
___
#####Параметры  
(_Обязательное_) position [String]: "38.898, -77.037"  
(_Обязательное_) name [String]: "Mercedes"  
(_Опциональное_) active [Boolean]: true  
___
#####Ответ
```json
{ success: true }
```
___
#####Ошибки
**HTTP Status: 404**
```json
{ error: "Name not provided" }```
В случае если имя не указано

**HTTP Status: 404**
```json
{ error: "Car not found" }```
В случае если автомобиль с данным именем не найден

**HTTP Status: 403**
```json
{ error: "Coordinates not provided or malformed" }```
В случае если координаты указаны неверно

## Список автомобилей
#####Запрос  
`GET /cars`  
___
#####Ответ
```json
[ { name: "Mercedes", active: true, position: [ 36.839, 77.321] } ]
```

## Расчёт прибытия
#####Запрос  
`GET /car/arrival`  
___
#####Параметры  
(_Обязательное_) position [String]: "38.898, -77.037"  
___
#####Ответ
```json
{ eta: "Среднее время подачи: 15 минут(а)" }
```
#####Ошибки
**HTTP Status: 403**
```json
{ error: "Coordinates not provided or malformed" }```
В случае если координаты указаны неверно

**HTTP Status: 404**
```json
{ error: "Не найдено подходящих автомобилей" }```
В случае если координаты указаны неверно