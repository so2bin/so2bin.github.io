---
title: Go sync.Map
date: 2024-05-06 15:37:34
---
## 作用
* 并发安全的map操作数据结构，适用于“读多写少”和不同协程写不同的key子集的场景；

## 原理
1. 读写分离

* `sync.Map`结构中，定义了一个只读的`read` `atmoic.Pointer`，和一个用于记录写/删操作的`dirty` `atmoic.Pointer`，如下图所示：
```go
type Map struct {
	mu Mutex

	// 并发只读对象，是一个原子指针，需要用到原子锁
	read atomic.Pointer[readOnly]

	// 脏数据，用于写/删操作
	dirty map[any]*entry

	// 统计read中读不到的资源，达到一定阈值，会将dirty promote为read
	misses int
}
```
<!-- more -->
* 其读操作是优先从`read`中取值，如果`read`中没值，才会从`dirty`中取值；
```go
// Load returns the value stored in the map for a key, or nil if no
// value is present.
// The ok result indicates whether value was found in the map.
func (m *Map) Load(key any) (value any, ok bool) {
	read := m.loadReadOnly()
	e, ok := read.m[key]   // 这里不需要锁，是因为read.m是会保证readonly
	if !ok && read.amended {
		m.mu.Lock()        // 需要大锁
		// Avoid reporting a spurious miss if m.dirty got promoted while we were
		// blocked on m.mu. (If further loads of the same key will not miss, it's
		// not worth copying the dirty map for this key.)
        // 双重确认
		read = m.loadReadOnly()
		e, ok = read.m[key]
        // read.amended=true代表dirty中有更新值
		if !ok && read.amended {
			e, ok = m.dirty[key]
			// Regardless of whether the entry was present, record a miss: this key
			// will take the slow path until the dirty map is promoted to the read
			// map.
			m.missLocked()
		}
		m.mu.Unlock()
	}
	if !ok {
		return nil, false
	}
	return e.load()
}
```
* 这里的`missLocked`有额外的逻辑：当misses超出一定阈值时，此时先读`read`再读`dirty`的代价比直接从`dirty`读更大，所以这里直接将`dirty`的值promote为`read`值：
```go
func (m *Map) missLocked() {
	m.misses++
	if m.misses < len(m.dirty) {
		return
	}
	m.read.Store(&readOnly{m: m.dirty})
	m.dirty = nil
	m.misses = 0
}
```

* 写操作
```go
// Swap swaps the value for a key and returns the previous value if any.
// The loaded result reports whether the key was present.
func (m *Map) Swap(key, value any) (previous any, loaded bool) {
	read := m.loadReadOnly()
	if e, ok := read.m[key]; ok {
        // 如果e.p == nil 或e.p == expunged，则会返回false，此时代表已经标签删除
        // 这里如果read中直接有key值，则直接swap即可，不用考虑dirty的情况
		if v, ok := e.trySwap(&value); ok { 
			if v == nil {
				return nil, false
			}
			return *v, true
		}
	}
    // read中没找到或被标记删除
	m.mu.Lock()
	read = m.loadReadOnly()
	if e, ok := read.m[key]; ok {
		if e.unexpungeLocked() { // e.p == expunged -> e.p = nil
			// The entry was previously expunged, which implies that there is a
			// non-nil dirty map and this entry is not in it.
			m.dirty[key] = e
		}
        // 交换最新值，此时的e已经被移到了dirty中，所以后续的读，只会在dirty中读到该值
		if v := e.swapLocked(&value); v != nil {
			loaded = true
			previous = *v
		}
	} else if e, ok := m.dirty[key]; ok { // 已经在dirty中，直接交换
		if v := e.swapLocked(&value); v != nil {
			loaded = true
			previous = *v
		}
	} else {
		if !read.amended {  // 新增值，标记amended
			// We're adding the first new key to the dirty map.
			// Make sure it is allocated and mark the read-only map as incomplete.
			m.dirtyLocked()
			m.read.Store(&readOnly{m: read.m, amended: true})
		}
		m.dirty[key] = newEntry(value)
	}
	m.mu.Unlock()
	return previous, loaded
}


func (e *entry) trySwap(i *any) (*any, bool) {
    // 这里用for循环，是考虑了Load和CompareAndSwap之间出现p值变化的情况
	for {
		p := e.p.Load()
		if p == expunged {
			return nil, false
		}
        // p值存在，则赋值为i，并返回p
		if e.p.CompareAndSwap(p, i) {
			return p, true
		}
	}
}

```

2. 延迟删除和更新

3. 原子操作：read操作中也不是完全无锁，只是用了粒度更小更高效的原子锁；


