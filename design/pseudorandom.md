# 疑似乱数

疑似乱数生成で使用する共通型は「[型定義](types.md)」の「疑似乱数内部型」を参照.

## 概要

クライアントおよびサーバの共通の乱数生成式


## 疑似乱数生成式

### Rust

```Rust
const RNG_MULTIPLIER: u64 = 6364136223846793005;
const RNG_INCREMENT: u64 = 1442695040888963407;

pub struct Random {
    state: u64,
}

impl Random {
    pub fn new(seed: u64) -> Self {
        let mut rand = Self {
            state: 0,
        };

        let _ = rand.next_u32();
        rand.state = rand.state.wrapping_add(seed);
        let _ = rand.next_u32();

        rand
    }

    pub fn next_u32(&mut self) -> u32 {
        let old_state = self.state;

        self.state = old_state
            .wrapping_mul(RNG_MULTIPLIER)
            .wrapping_add(RNG_INCREMENT);

        let xorshifted = (((old_state >> 18) ^ old_state) >> 27) as u32;

        let rotation = (old_state >> 59) as u32;

        xorshifted.rotate_right(rotation)
    }

    pub fn next_bounded(&mut self, bound: u32) -> u32 {
        if bound == 0 {
            return 0;
        }

        let threshold = bound.wrapping_neg() % bound;

        loop {
            let value = self.next_u32();

            if value >= threshold {
                return value % bound;
            }
        }
    }
}

```

### C++

```C++
#include <cstdint>

class Random {
private:
    std::uint64_t state;

public:
    explicit Random(const std::uint64_t seed) : state(0) {
        static_cast<void>(this->next_u32());
        this->state += seed;
        static_cast<void>(this->next_u32());
    }

    [[nodiscard]] std::uint32_t next_u32() noexcept {
        constexpr std::uint64_t MULTIPLIER = UINT64_C(6364136223846793005);
        constexpr std::uint64_t INCREMENT  = UINT64_C(1442695040888963407);

        const std::uint64_t old_state = this->state;
        this->state = old_state * MULTIPLIER + INCREMENT;

        const auto xorshifted = static_cast<std::uint32_t>(((old_state >> 18U) ^ old_state) >> 27U);
        const auto rotation = static_cast<std::uint32_t>(old_state >> 59U);

        return this->rotate_right(xorshifted, rotation);
    }

    [[nodiscard]] std::uint32_t next_bounded(const std::uint32_t bound) noexcept {
        if (bound == 0U) {
            return 0U;
        };

        const std::uint32_t threshold = static_cast<std::uint32_t>(-bound) % bound;
        for (;;) {
            const std::uint32_t value = this->next_u32();
            if (value >= threshold) {
                return value % bound;
            }
        }
    }

private:
    [[nodiscard]] static constexpr std::uint32_t rotate_right(const std::uint32_t value,const  std::uint32_t rotation) noexcept {
        constexpr std::uint32_t BIT_COUNT = 32U;
        rotation &= BIT_COUNT - 1U;
        return (value >> rotation) | (value << ((BIT_COUNT - rotation) & (BIT_COUNT - 1U)));
    }
};
```

## 確率計算

```
精度 = 10000
p = (next_bounded(精度) as f32) / (精度 as f32)
結果 = 判定したい確率 > p
```

## 範囲乱数

```
index = next_bounded(乱数の範囲)
倍率 = 1.0 + index * 0.0001
```

## 抽選

アルゴリズムは「フィッシャー–イェーツのシャッフル」を使用する.


### Rust

```Rust
pub fn shuffle<T>(values: &mut [T], random: &mut Random) {
    for i in (1..values.len()).rev() {
        let j = random.next_bounded((i + 1) as u32) as usize;
        values.swap(i, j);
    }
}
```

### C++

```C++
#include <cstddef>
#include <cstdint>
#include <utility>
#include <vector>

template <typename T>
void shuffle(std::vector<T>& values, Random& random) {
    for (std::size_t i = values.size(); i > 1U; --i) {
        const auto j = static_cast<std::size_t>(
            random.next_bounded(static_cast<std::uint32_t>(i))
        );
        std::swap(values[i - 1U], values[j]);
    }
}
```

## 重み付き抽選

### Rust

```Rust
pub fn weighted_shuffle<T>(values: &mut [T], weights: &mut [u32], random: &mut Random) {
    for i in 0..values.len() {
        let total: u32 = weights[i..].iter().sum();
        let mut value = random.next_bounded(total);
        let mut j = i;

        while value >= weights[j] {
            value -= weights[j];
            j += 1;
        }

        values.swap(i, j);
        weights.swap(i, j);
    }
}
```

### C++

```C++
template <typename T>
void weighted_shuffle(std::vector<T>& values, std::vector<std::uint32_t>& weights, Random& random) {
    for (std::size_t i = 0U; i < values.size(); ++i) {
        std::uint32_t total = 0U;
        for (std::size_t j = i; j < weights.size(); ++j) {
            total += weights[j];
        }

        std::uint32_t value = random.next_bounded(total);
        std::size_t j = i;
        while (value >= weights[j]) {
            value -= weights[j++];
        }

        std::swap(values[i], values[j]);
        std::swap(weights[i], weights[j]);
    }
}
```

